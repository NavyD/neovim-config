# nsuda — Neovim sudo plugin, Lua rewrite of suda.vim

## 1. 背景

suda.vim 是一个 Vim/Neovim 插件，通过 `sudo` 命令实现提权读写文件。核心机制：注册 `suda://` 协议，拦截 `BufReadCmd`/`BufWriteCmd` 自动命令。在 Windows 上存在两个重大 bug：

1. **tee.exe 挂起 + 源文件被清空**：`SudaWrite` 执行 `sudo tee target`，tee.exe 弹出窗口不退出，导致写入流程卡死，源文件可能被截断
2. **gsudo + 密码提示冲突**：设置 `g:suda#executable = 'gsudo'` 后，suda.vim 仍尝试 `inputsecret()` 密码输入，但 gsudo 走 UAC 机制无需密码，导致交互混乱，文件保存失败

nsuda 是 suda.vim 的 Lua 重写版，优先解决 Windows bug，同时使用 Neovim 0.12+ API 实现。

## 2. 设计目标

- **独立插件**：`lua/utils/nsuda/` 作为一个 lazy.nvim 本地插件
- **面向对象**：`Suda` 类封装所有状态（`_config`、`_augroup`、`_remembered`），不散落在模块级变量
- **只暴露 `setup()`**：不导出内部 `Suda` 类，用户只需 `setup(opts)` 一切自动工作
- **不一对一翻译**：使用 Neovim 原生 Lua API（`vim.uv`、`vim.fs`、`vim.system`）
- **Windows first**：从根源解决 suda.vim 的两个 bug
- **最小依赖**：无第三方 Lua 库
- **无向后兼容**：不读取 `vim.g` 旧变量

## 3. 类型定义

```lua
--- elevation_cmd_build 的上下文
---@class nsuda.ElevationCmdBuildCtx
---@field exe            string    提权可执行文件路径
---@field cmd            string[]  待执行的命令参数
---@field noninteractive boolean   静默模式标志

--- elevation_cmd_build 函数签名
--- 内部自行处理认证（缓存探测、密码输入），认证成功后返回待执行的完整命令参数列表。
--- 失败返回 nil, 错误信息。
---@alias nsuda.ElevationCmdBuildFn fun(ctx: nsuda.ElevationCmdBuildCtx): string[]?, string?

---@alias nsuda.ElevationCmdBuilds table<string, nsuda.ElevationCmdBuildFn>

--- 写入错误匹配上下文
---@class WriteErrorMatchCtx
---@field error string   pcall(vim.cmd, "write") 的错误信息
---@field path  string   目标文件绝对路径
---@field buf   integer  当前 buffer number

---@class nsuda.Config
---@field executable?                  string
---  提权可执行文件路径。未指定时自动探测：Linux → sudo，Windows → gsudo > sudo。
---@field noninteractive?              boolean
---  静默模式：不弹密码框、不弹确认框。默认 false。
---@field smart_edit?                  boolean
---  自动检测需提权文件并接管读写。默认 false。
---@field prompt?                      string
---  密码提示符。默认 "Password: "（仅 sudo builder 内部使用）。
---@field elevation_cmd_builds?        nsuda.ElevationCmdBuilds
---  提权命令构建函数表。key 为 `elevation_cmd_build_match_fn` 返回的工具名，value 为构建函数。
---  内置 {sudo, gsudo.exe, sudo.exe}，用户可扩展/覆盖。
---@field elevation_cmd_build_match_fn? fun(exe: string): string
---  根据 executable 路径返回 elevation_cmd_builds 的 key。
---  默认：vim.fs.basename(exe)，Windows 额外转小写。
---@field write_error_match?           fun(ctx: WriteErrorMatchCtx): boolean
---  自定义写入错误判断。默认：匹配 "E212:" + ("permission denied" | "operation not permitted")。
```

## 4. 导出接口

```lua
---@class nsuda.Suda
local M = {}

---@param config? nsuda.Config
function M.setup(config) end

return M
```

唯一公开 API。`setup()` 内部：
1. 若 `config.executable` 未指定，调用 `find_exepath` 自动探测
2. 用 `vim.tbl_deep_extend("keep", config, default_config)` 合并配置（用户配置优先）
3. 创建 `Suda` 实例并调用 `:register()` 注册 autocmd 和用户命令

内部 `Suda` 实例方法（封装在类中，不导出）：
- `Suda:read(path)` — 提权读取文件（通过临时文件 + `dd`/`copy` 复制）
- `Suda:write(path, lines)` — 提权写入文件
- `Suda:exec(cmd)` — 提权执行命令
- `Suda:_elevate(cmd)` — 通过 `elevation_cmd_build_fn` 构建提权命令参数
- `Suda:handle_read(buf, path)` — 处理 `suda://` 协议的 BufReadCmd
- `Suda:handle_protocol_write(buf, path)` — 处理 `suda://` 协议的 BufWriteCmd
- `Suda:handle_smart_write(buf, path)` — smart_edit 模式的写入处理器
- `Suda:handle_buf_enter(buf, name)` — smart_edit 的 BufEnter 处理器
- `Suda:register()` — 注册所有 autocmd 和用户命令

模块级工具：
- `log` 表：`log.log(msg, level)` / `log.info(msg)` / `log.error(msg)` / `log.warn(msg)` — 封装 `vim.notify`
- `raw_copy_cmd(src, dst)` — 平台原生复制命令（Linux: `dd`，Windows: `cmd /c copy /y`）
- `find_exepath(exes)` — 在候选列表中查找第一个存在的可执行文件路径

用户命令：
- `:SudaRead [path]` — 提权打开文件（不指定则使用当前 buffer 路径）
- `:SudaWrite [path]` — 提权保存文件（不指定则使用当前 buffer 路径）

## 5. Suda 类设计

所有状态封装在 `Suda` 实例中，不散落在模块级变量。

```lua
local Suda = {}

function Suda.new(config)
  return setmetatable({
    _config     = config,        -- nsuda.Config  合并后的配置
    _augroup    = augroup_id,    -- integer       nvim_create_augroup("nsuda", {clear = true})
    _remembered = {},            -- {[dir] = true} 记住的目录
    _matcher    = nil,           -- 预留字段（未使用）
  }, { __index = Suda })
end

function Suda:register()
  -- BufReadCmd / BufWriteCmd for suda://
  -- smart_edit BufEnter (if enabled)
  -- :SudaRead / :SudaWrite commands
end

-- 实例方法
function Suda:exec(cmd)
  local args, err = self:_elevate(cmd)
  if not args then return err end
  local o = vim.system(args, {text = true}):wait()
  if o.code ~= 0 then
    return "Failed to run cmd=" .. vim.inspect(args)
      .. " with code=" .. o.code .. " stderr=" .. (o.stderr or "")
  end
  return nil
end
```

相比于 v1 设计规范，实际实现的差异：
- 移除了 `_builds` / `_matcher` 实例字段 → 直接使用 `config.elevation_cmd_builds` / `config.elevation_cmd_build_match_fn`
- `_group` → `_augroup`
- `new` 接收已合并的 `config` 而非原始 `opts`
- `exec` 返回 `string? error` 而非 `SystemResult`

## 6. elevation_cmd_build 架构

### 6.1 核心思想

`elevation_cmd_build_fn(ctx: ElevationCmdBuildCtx): string[]?, string?` 是一个函数，**全权负责认证**——内部自行 `vim.system` 做缓存探测、密码认证，认证成功后返回待执行的命令参数列表。认证失败返回 `nil, reason`。

Suda 不知道 `-n`/`-S`/`inputsecret`/`UAC` 这些概念，只调用 `elevation_cmd_build_fn` 拿结果。

### 6.2 Suda 使用流程

```lua
function Suda:_elevate(cmd)
  local conf = self._config
  local exe = conf.executable
  local key = conf.elevation_cmd_build_match_fn(exe)  -- "sudo" / "gsudo.exe" / "sudo.exe"
  local f = conf.elevation_cmd_builds[key]
  if not f then
    return nil, "no elevation build for: " .. key
  end
  return f({ exe = exe, cmd = cmd, noninteractive = conf.noninteractive })
end

function Suda:exec(cmd)
  local args, err = self:_elevate(cmd)
  if not args then return err end
  local o = vim.system(args, {text = true}):wait()
  if o.code ~= 0 then
    return "Failed to run cmd=" .. vim.inspect(args)
      .. " with code=" .. o.code .. " stderr=" .. (o.stderr or "")
  end
  return nil
end
```

### 6.3 内置 build 函数

```lua
local default_builds = {
  --- sudo (Unix): 缓存探测 → inputsecret 密码认证
  sudo = function(ctx)
    local exe, cmd = ctx.exe, ctx.cmd
    -- 1. 缓存探测
    local r = vim.system({exe, "-n", "true"}, {text = true}):wait()
    if r.code == 0 then
      return {exe, unpack(cmd)}
    end
    if ctx.noninteractive then
      return nil, "sudo authentication required"
    end
    -- 2. 密码认证
    local pwd = vim.fn.inputsecret("Sudo password: ")
    if #pwd == 0 then return nil, "cancelled" end
    local ar = vim.system({exe, "-S", "-p", "", "true"}, {text = true, stdin = pwd .. "\n"}):wait()
    if ar.code ~= 0 then
      return nil, "sudo authentication failed"
    end
    return {exe, unpack(cmd)}
  end,

  --- gsudo (Windows UAC): 缓存探测 + 自动启用
  ["gsudo.exe"] = function(ctx)
    -- 1. 检查 gsudo 状态
    local r = vim.system({ctx.exe, "status", "--json"}, {text = true}):wait()
    if r.code ~= 0 then
      return nil, r.stderr
    end
    local ok, res = pcall(vim.json.decode, r.stdout)
    if not ok then return nil, res end
    -- 2. 若未缓存，自动启用
    if not res["CacheAvailable"] then
      local ele_cmd = {ctx.exe, "cache", "on", "-p", vim.uv.os_getpid()}
      local ele_res = vim.system(ele_cmd):wait()
      if ele_res.code ~= 0 then
        return nil, "Failed to run cmd=" .. vim.inspect(ele_cmd)
          .. " with error: " .. (ele_res.stderr or "")
      end
    end
    return {ctx.exe, unpack(ctx.cmd)}, nil
  end,

  --- sudo.exe (Windows 上的 sudo，Win11+): 直接透传
  ["sudo.exe"] = function(ctx)
    return {ctx.exe, unpack(ctx.cmd)}
  end,
}
```

> **runas** (Windows fallback) 已注释，内置 builds 中不再包含。

### 6.4 elevation_cmd_build_match_fn

默认匹配逻辑：

```lua
elevation_cmd_build_match_fn = function(exe)
  local name = vim.fs.basename(exe)
  if is_windows then
    name = name:lower()  -- "GSudo.exe" → "gsudo.exe"
  end
  return name
end
```

注意：Windows 上保留完整扩展名（`sudo.exe`、`gsudo.exe`），不做 strip。这允许 `sudo.exe` 和 `gsudo.exe` 使用不同的 builder。

## 7. API 选择：`vim.uv` / `vim.fs` 替代 `vim.fn.*`

| 用途 | 旧的 vim.fn | 新的 |
|------|------------|------|
| 文件是否存在 | `filereadable()` / `getftype()` | `vim.uv.fs_stat(path)` — nil 表示不存在 |
| 读权限 | `filereadable()` | `vim.uv.fs_access(path, "R")` |
| 写权限 | `filewritable()` | `vim.uv.fs_access(path, "W")` |
| 是否目录 | `isdirectory()` | `stat.type == "directory"` |
| 父目录 | `fnamemodify(x, ":h")` | `vim.fs.dirname(x)` |
| 绝对路径 | `fnamemodify(x, ":p")` | `vim.fn.fnamemodify(vim.fn.expand(path), ":p")` |
| 可执行文件查找 | `executable()` | `vim.fn.exepath(name)` — 返回完整路径 |

> `vim.uv.fs_access` 在 Windows 受保护目录和 `filewritable()` 一样不可靠。E212 安全网兜底。

## 8. Smart Edit 机制

### 8.1 触发时机

`BufEnter` autocmd（`smart_edit = true`），仅普通文件 buffer。

### 8.2 排除条件

- `vim.b[buf]._suda_checked == true`（已处理过的 buffer）
- `vim.bo.buftype ~= ""`
- 路径匹配 `%w+://` 协议
- `stat.type == "directory"`

### 8.3 判断逻辑

```
stat = vim.uv.fs_stat(name)

├─ stat 存在:
│   ├─ type == "directory" → 不干预
│   │
│   ├─ type == "file":
│   │   ├─ vim.uv.fs_access(name, "W") → 不干预
│   │   └─ not vim.uv.fs_access(name, "W") → buftype=acwrite + BufWriteCmd
│   │
├─ stat 不存在:
│    逐级向上 vim.fs.dirname(parent):
│      parent_stat = vim.uv.fs_stat(parent)
│      ├─ type=="directory" + fs_access(parent, "W") → 不干预
│      ├─ type=="directory" + not fs_access(parent, "W") → buftype=acwrite + BufWriteCmd
│      └─ nil → 继续向上（找不到存在的目录 → 不干预）
└─ 其他 → 不干预
```

### 8.4 注册

设置 `buftype=acwrite` + 注册 buffer-local `BufWriteCmd` autocmd，回调调用 `self:handle_smart_write(buf, path)`。

## 9. 写入流程（handle_smart_write）

```
Suda:handle_smart_write(buf, path):
  1. doautocmd BufWritePre
  2. 尝试原生写入:
     保存 buftype → 设为 "" → pcall(vim.cmd, "noautocmd write") → 恢复 buftype
     ok → nomodified, doautocmd BufWritePost ✓

     构造 ctx = { error = tostring(err), path = path, buf = buf }
     if not self._config.write_error_match(ctx) then
       原样通知 err, doautocmd BufWritePost ✗  (不是权限问题)
     end

  3. 写入 tempfile:
     vim.cmd("noautocmd write! " .. vim.fn.fnameescape(tempfile))

  4. 确认/静默:
     self._config.noninteractive → 跳 5
     否则 → "[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"
       Y → 5
       R → 5 + vim.fs.dirname(path) 加入 self._remembered
       N → modified 不变, 清 tempfile, 取消通知 ✗

  5. 提权复制 tempfile → path:
     exec_err = self:exec(raw_copy_cmd(tempfile, path))
     not exec_err → nomodified, 保存成功通知 ✓
     exec_err → modified 不变, 通知错误 ✗

  6. vim.uv.fs_unlink(tempfile)
  7. doautocmd BufWritePost
```

## 10. 读取流程（handle_read）

```
Suda:handle_read(buf, path):
  1. log.info("reading buf=" .. buf .. " for path=" .. path)
  2. doautocmd BufReadPre
  3. 暂存 undolevels, 禁用 swapfile/undofile
  4. ok, lines = pcall(self.read, self, path)
     ok → 清空 buffer, 设置内容, buftype=acwrite, nomodified, filetype detect
     not ok → 报错
  5. 恢复 undolevels
  6. doautocmd BufReadPost
```

> `pcall(self.read, self, path)` 中 `self.read` 是从 `__index` 获取的 `Suda.read` 函数，通过 `pcall` 以 `(self_instance, path_string)` 调用，与 `function Suda:read(path)` 签名吻合。

## 11. 确认对话框

### 11.1 触发条件

- `write_error_match` 返回 true
- `self._config.noninteractive = false`

### 11.2 交互

```
"[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"

Y → 提权写入
R → 提权写入 + 目录记入 self._remembered
N → 取消
```

### 11.3 Remember

- `self._remembered` table，key 为目录绝对路径
- 命中 → 跳过确认，直接提权
- nvim 重启清空

## 12. 平台与可执行文件检测

### 12.1 自动探测

```lua
---@param exes string[]
local function find_exepath(exes)
  for _, name in ipairs(exes) do
    local p = vim.fn.exepath(name)
    if p then return p end
  end
  return nil
end
```

在 `M.setup()` 中调用：

```
config.executable 未指定时:
  Windows → find_exepath({"gsudo", "sudo"})
  Unix    → find_exepath({"sudo"})
  均未找到 → log.error("Not found any exe") + return
```

### 12.2 平台判断

```lua
local is_windows = vim.uv.os_uname().sysname == "Windows_NT"
```

## 13. 配置项一览

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `executable` | string? | auto-detect | 提权可执行文件完整路径 |
| `noninteractive` | boolean | false | 静默模式 |
| `smart_edit` | boolean | false | 自动接管需提权 buffer |
| `prompt` | string | "Password: " | 密码提示（由 sudo builder 内部 `inputsecret` 使用） |
| `elevation_cmd_builds` | table<string, fun>? | {sudo, gsudo.exe, sudo.exe} | 提权命令构建函数 |
| `elevation_cmd_build_match_fn` | fun(exe): string? | basename + Win 小写 | executable → key 映射 |
| `write_error_match` | fun(ctx): bool? | E212+perm 匹配 | 自定义写入错误判断 |

## 14. 内置依赖与日志

### 14.1 日志模块

```lua
local log = {}
function log.log(msg, level)   vim.notify(msg, level) end
function log.info(msg)          log.log(msg, vim.log.levels.INFO) end
function log.error(msg)         log.log(msg, vim.log.levels.ERROR) end
function log.warn(msg)          log.log(msg, vim.log.levels.WARN) end
```

用于 `Suda:handle_read`、`Suda:handle_smart_write` 的进入日志，`M.setup` 的配置打印，以及 `find_exepath` 失败时的错误通知。

### 14.2 配置合并策略

```lua
config = vim.tbl_deep_extend("keep", config or {}, default_config)
```

使用 `"keep"` 策略：用户指定的字段保留，未指定的字段从 `default_config` 继承。这意味着 `executable` 若用户在 lazy.nvim opts 中不指定，则由 `M.setup` 自动探测后填入 `config` 表，再与 `default_config` 合并。

### 14.3 _matcher 字段

`Suda:new()` 中初始化了 `_matcher = nil` 字段，当前未使用，为预留字段。实际匹配通过 `config.elevation_cmd_build_match_fn` 直接调用。

## 15. 不属于本设计

- FileWriteCmd（`:w suda://` 以外的写出场景）
- 密码缓存 / sudo timestamp 管理（依赖外部 sudo/gsudo 配置）
- 向后兼容 `vim.g`

## 16. 与原始 suda.vim 的设计差异汇总

| 方面 | suda.vim | nsuda |
|------|----------|-------|
| 状态管理 | 模块级变量 (`g:suda#*`) | `Suda` 实例封装 |
| 提权架构 | 内联的 `tee` / `cat` 管道 | `elevation_cmd_build_fn` 策略模式 |
| Windows 写入 | `tee.exe` → 挂起风险 | `cmd /c copy` 临时文件 |
| gsudo 认证 | 独立 password 提示冲突 | `gsudo status --json` + `cache on` 自动管理 |
| 可执行文件查找 | `vim.fn.executable` | `vim.fn.exepath`（返回完整路径） |
| 配置合并 | 无（各自读 vim.g） | `tbl_deep_extend("keep")` |
| Windows sudo | 无 | 支持 `sudo.exe`（Win11+） |
| 日志 | 无 | `log` 模块封装 `vim.notify` |
