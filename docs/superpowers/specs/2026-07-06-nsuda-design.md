# nsuda — Neovim sudo plugin, Lua rewrite of suda.vim

## 1. 背景

suda.vim 是一个 Vim/Neovim 插件，通过 `sudo` 命令实现提权读写文件。核心机制：注册 `suda://` 协议，拦截 `BufReadCmd`/`BufWriteCmd` 自动命令。在 Windows 上存在两个重大 bug：

1. **tee.exe 挂起 + 源文件被清空**：`SudaWrite` 执行 `sudo tee target`，tee.exe 弹出窗口不退出，导致写入流程卡死，源文件可能被截断
2. **gsudo + 密码提示冲突**：设置 `g:suda#executable = 'gsudo'` 后，suda.vim 仍尝试 `inputsecret()` 密码输入，但 gsudo 走 UAC 机制无需密码，导致交互混乱，文件保存失败

nsuda 是 suda.vim 的 Lua 重写版，优先解决 Windows bug，同时使用 Neovim 0.12+ API 实现。

## 2. 设计目标

- **独立插件**：`lua/utils/nsuda/` 作为一个 lazy.nvim 本地插件
- **面向对象**：`Suda` 类封装所有状态，不散落在模块级变量
- **只暴露 `setup()`**：不导出内部 API，用户只需 `setup(opts)` 一切自动工作
- **不一对一翻译**：使用 Neovim 原生 Lua API（`vim.uv`、`vim.fs`、`vim.system`）
- **Windows first**：从根源解决 suda.vim 的两个 bug
- **最小依赖**：无第三方 Lua 库
- **无向后兼容**：不读取 `vim.g` 旧变量

## 3. 类型定义

```lua
--- 写入错误上下文
---@class nsuda.WriteCtx
---@field error  string   pcall(vim.cmd, "write") 的错误信息
---@field path   string   目标文件绝对路径
---@field buf    integer  当前 buffer number

--- elevation_cmd_build 的上下文
---@class nsuda.CmdCtx
---@field noninteractive  boolean  静默模式
---@field prompt          string   密码提示符

--- elevation_cmd_build 函数签名
--- 内部自行处理认证（缓存探测、密码输入），认证成功后返回待执行的命令参数
--- 返回 nil, err_reason 表示认证失败或用户取消
---@alias nsuda.ElevationCmdBuild fun(cmd: string[], ctx: nsuda.CmdCtx): string[]?, string?

--- elevation_cmd_matcher 函数签名
--- 根据 executable 路径返回 elevation_cmd_builds 的 key
---@alias nsuda.ElevationCmdMatcher fun(exe: string): string

---@class nsuda.Config
---@field executable?               string
---  提权可执行文件路径。Unix 默认 "sudo"，Windows 默认 gsudo > sudo(Win11) > runas。
---@field noninteractive?           boolean
---  静默模式：不弹密码框、不弹确认框。默认 false。
---@field prompt?                   string
---  密码提示符。默认 "Password: "。
---@field smart_edit?               boolean
---  自动检测需提权文件并接管读写。默认 false。
---@field write_error_handler?      fun(ctx: nsuda.WriteCtx): boolean
---  自定义写入错误判断。默认：匹配 "E212:" + ("permission denied" | "operation not permitted")。
---@field elevation_cmd_builds?     table<string, nsuda.ElevationCmdBuild>
---  提权命令构建函数表。key 为工具名，value 为 elevation_cmd_build 函数。
---  内置 {sudo, gsudo, runas}，用户可扩展/覆盖。
---@field elevation_cmd_matcher?    nsuda.ElevationCmdMatcher
---  根据 executable 路径返回 elevation_cmd_builds 的 key。
---  默认：vim.fs.basename(exe)，Windows 额外 strip 扩展名。
```

## 4. 导出接口

```lua
---@class nsuda.Suda
local M = {}

---@param config? nsuda.Config
function M.setup(config) end

return M
```

唯一公开 API。`setup()` 内部创建 `Suda` 实例、注册 autocmd 和用户命令。

用户命令：
- `:SudaRead [path]` — 提权打开文件
- `:SudaWrite [path]` — 提权保存文件

## 5. Suda 类设计

所有状态封装在 `Suda` 实例中，不散落在模块级变量。

```lua
local Suda = {}
Suda.__index = Suda

function Suda:new(opts)
  return setmetatable({
    _config      = extend(defaults, opts),
    _group       = -1,          -- augroup ID
    _remembered  = {},          -- {[dir] = true}
    _builds      = {},          -- merged elevation_cmd_builds
    _matcher     = nil,         -- elevation_cmd_matcher
  }, Suda)
end

function Suda:register()
  self._group = vim.api.nvim_create_augroup("nsuda", { clear = true })
  -- BufReadCmd / BufWriteCmd for suda://
  -- smart_edit BufEnter
  -- :SudaRead / :SudaWrite commands
end

-- 实例方法
function Suda:exec(cmd)
  -- raw copy: dd / cmd /c copy /y
  local args, err = self:_elevate(copy_cmd, {noninteractive=..., prompt=...})
  if not args then return nil, err end
  return vim.system(args, {text = true}):wait()
end
```

## 6. elevation_cmd_build 架构

### 6.1 核心思想

`elevation_cmd_build(cmd, ctx): string[]?, string?` 是一个函数，**全权负责认证**——内部自行 `vim.system` 做缓存探测、密码认证，认证成功后返回待执行的命令参数列表。认证失败返回 `nil, reason`。

Suda 不知道 `-n`/`-S`/`inputsecret`/`UAC` 这些概念，只调用 `elevation_cmd_build` 拿结果。

### 6.2 内置 build 函数

```lua
local default_builds = {
  --- sudo (Unix): 缓存 → inputsecret 密码
  sudo = function(cmd, ctx)
    -- 1. 缓存探测
    local r = vim.system({"sudo", "-n", "true"}, {text = true}):wait()
    if r.code == 0 then
      return {"sudo", unpack(cmd)}
    end
    if ctx.noninteractive then
      return nil, "sudo authentication required"
    end
    -- 2. 密码认证
    local pwd = vim.fn.inputsecret(ctx.prompt)
    if #pwd == 0 then return nil, "cancelled" end
    local ar = vim.system({"sudo", "-S", "-p", "", "true"}, {text = true, stdin = pwd .. "\n"}):wait()
    if ar.code ~= 0 then
      return nil, "sudo authentication failed"
    end
    return {"sudo", unpack(cmd)}
  end,

  --- gsudo (Windows UAC): 直接透传
  gsudo = function(cmd, ctx)
    return {"gsudo", unpack(cmd)}
  end,

  --- runas (Windows fallback): batch + runas
  runas = function(cmd, ctx)
    return {"runas", "/noprofile", "/user:Administrator", unpack(cmd)}
  end,
}
```

### 6.3 Suda 使用流程

```lua
function Suda:_elevate(cmd)
  local key = self._matcher(self._config.executable)
  local f = self._builds[key]
  if not f then
    return nil, "no elevation build for: " .. key
  end
  return f(cmd, {
    noninteractive = self._config.noninteractive,
    prompt = self._config.prompt,
  })
end

function Suda:exec(cmd)
  local args, err = self:_elevate(cmd)
  if not args then return {code = -1, stderr = err} end
  return vim.system(args, {text = true}):wait()
end
```

### 6.4 elevation_cmd_matcher

默认匹配逻辑：

```lua
local function default_matcher(exe)
  local name = vim.fs.basename(exe)
  if vim.uv.os_uname().sysname == "Windows_NT" then
    name = name:gsub("%.[^.\\/]+$", "")  -- strip .exe/.bat/.cmd/.ps1/.com
  end
  return name
end
```

## 7. API 选择：`vim.uv` / `vim.fs` 替代 `vim.fn.*`

| 用途 | 旧的 vim.fn | 新的 |
|------|------------|------|
| 文件是否存在 | `filereadable()` / `getftype()` | `vim.uv.fs_stat(path)` — nil 表示不存在 |
| 读权限 | `filereadable()` | `vim.uv.fs_access(path, "R")` |
| 写权限 | `filewritable()` | `vim.uv.fs_access(path, "W")` |
| 是否目录 | `isdirectory()` | `stat.type == "directory"` |
| 父目录 | `fnamemodify(x, ":h")` | `vim.fs.dirname(x)` |
| 绝对路径 | `fnamemodify(x, ":p")` | `vim.uv.fs_realpath(x)` |

> `vim.uv.fs_access` 在 Windows 受保护目录和 `filewritable()` 一样不可靠。E212 安全网兜底。

## 8. Smart Edit 机制

### 8.1 触发时机

`BufEnter` autocmd（`smart_edit = true`），仅普通文件 buffer。

### 8.2 排除条件

- `vim.bo.buftype ~= ""`
- 路径匹配 `%w+://` 协议
- `stat.type == "directory"`
- `vim.b.suda_checked == true`

### 8.3 判断逻辑

```
stat = vim.uv.fs_stat(path)

├─ stat 存在 + type=="file":
│   ├─ vim.uv.fs_access(path, "W") → 不干预
│   ├─ not vim.uv.fs_access(path, "W") → buftype=acwrite + BufWriteCmd
│   └─ not vim.uv.fs_access(path, "R") → suda://
│
├─ stat 不存在:
│    逐级向上 vim.fs.dirname(parent):
│      parent_stat = vim.uv.fs_stat(parent)
│      ├─ type=="directory" + fs_access(parent, "W") → 不干预
│      ├─ type=="directory" + not fs_access(parent, "W") → buftype=acwrite
│      └─ nil → 继续向上（找不到存在的目录 → 不干预）
└─ 其他 → 不干预
```

### 8.4 注册

设置 `buftype=acwrite` + 注册 buffer-local `BufWriteCmd` autocmd。

## 9. 写入流程（BufWriteCmd handler）

```
Suda:handle_smart_write(buf, path):
  1. doautocmd BufWritePre

  2. 尝试原生写入:
     vim.bo[buf].buftype = ""
     local ok, err = pcall(vim.cmd, "write")
     ok → 恢复 buftype=acwrite, nomodified, doautocmd BufWritePost ✓

     local ctx = { error = err, path = path, buf = buf }
     if not self._config.write_error_handler(ctx) then
       恢复 buftype, 原样通知 err ✗
     end

  3. 写入 tempfile:
     vim.cmd("noautocmd write " .. vim.fn.fnameescape(tempfile))

  4. 确认/静默:
     self._config.noninteractive → 跳 5
     否则 → "[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"
       Y → 5
       R → 5 + vim.fs.dirname(path) 加入 self._remembered
       N → modified 不变, 清 tempfile

  5. 提权复制 tempfile → path:
     r = self:exec(copy_cmd(tempfile, path))
     r.code == 0 → 恢复 buftype, nomodified, doautocmd BufWritePost ✓
     r.code != 0 → modified 不变, 通知 r.stderr ✗

  6. vim.uv.fs_unlink(tempfile)
```

## 10. 读取流程（BufReadCmd handler）

```
Suda:handle_read(buf, path):
  1. doautocmd BufReadPre
  2. 暂存 undolevels, 禁用 swapfile/undofile
  3. tempfile = vim.fn.tempname()
  4. r = self:exec(copy_cmd(path, tempfile))
     r.code != 0 → 报错 r.stderr, 清 tempfile, 恢复 ✗
  5. readfile(tempfile, "b"), 清旧内容, buftype=acwrite, nomodified
  6. vim.uv.fs_unlink(tempfile)
  7. doautocmd BufReadPost
```

## 11. 确认对话框

### 11.1 触发条件

- `write_error_handler` 返回 true
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

```
Suda._detect_executable():
  Unix → "sudo"

  Windows:
    vim.fn.executable("gsudo") == 1 → "gsudo"
    vim.fn.executable("sudo") == 1  → "sudo" (Win11)
    → "runas"  （系统自带，fallback）
```

## 13. 配置项一览

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `executable` | string? | auto-detect | 提权可执行文件路径 |
| `noninteractive` | boolean | false | 静默模式 |
| `prompt` | string | "Password: " | 密码提示（由 elevation_cmd_build 内部使用） |
| `smart_edit` | boolean | false | 自动接管需提权 buffer |
| `write_error_handler` | fun(ctx): bool | E212+perm 匹配 | 自定义写入错误判断 |
| `elevation_cmd_builds` | table<string, fun>? | {sudo, gsudo, runas} | 提权命令构建函数 |
| `elevation_cmd_matcher` | fun(exe): string? | basename + Win strip 扩展名 | executable → key 映射 |

## 14. 不属于本设计

- FileWriteCmd（`:w suda://` 以外的写出场景）
- 密码缓存 / sudo timestamp 管理（依赖外部 sudo 配置）
- 向后兼容 `vim.g`
