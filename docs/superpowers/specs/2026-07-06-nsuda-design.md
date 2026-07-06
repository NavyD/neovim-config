# nsuda — Neovim sudo plugin, Lua rewrite of suda.vim

## 1. 背景

suda.vim 是一个 Vim/Neovim 插件，通过 `sudo` 命令实现提权读写文件。核心机制：注册 `suda://` 协议，拦截 `BufReadCmd`/`BufWriteCmd` 自动命令。在 Windows 上存在两个重大 bug：

1. **tee.exe 挂起 + 源文件被清空**：`SudaWrite` 执行 `sudo tee target`，tee.exe 弹出窗口不退出，导致写入流程卡死，源文件可能被截断
2. **gsudo + 密码提示冲突**：设置 `g:suda#executable = 'gsudo'` 后，suda.vim 仍尝试 `inputsecret()` 密码输入，但 gsudo 走 UAC 机制无需密码，导致交互混乱，文件保存失败

nsuda 是 suda.vim 的 Lua 重写版，优先解决 Windows bug，同时使用 Neovim 0.12+ `vim.system()` API 实现。

## 2. 设计目标

- **独立插件**：`lua/suda.lua` 单文件，`setup()` 风格配置
- **不一对一翻译**：使用 Neovim 原生 Lua API（`vim.uv`、`vim.fs`、`vim.system`），不用 vimscript 遗留方式
- **Windows first**：从根源解决 suda.vim 的两个 bug
- **最小依赖**：无第三方 Lua 库、无外部工具（gsudo/sudo 除外）
- **无向后兼容**：不读取 `vim.g` 旧变量

## 3. 类型定义

```lua
--- 写入错误上下文
---@class nsuda.WriteCtx
---@field error  string   pcall(vim.cmd, "write") 的错误信息
---@field path   string   目标文件绝对路径
---@field buf    integer  当前 buffer number

--- 命令参数构建器：给任意命令加上提权前缀
---@class nsuda.ElevationBuilder
---@field build      fun(cmd: string[]): string[]          -- 免认证模式
---@field build_auth fun(cmd: string[]): string[]?         -- 密码模式，nil=不支持 stdin 密码

---@alias nsuda.Builders table<string, nsuda.ElevationBuilder>

---@class nsuda.SystemResult
---@field code    integer  退出码（0 成功）
---@field stdout  string   stdout 输出（原样，NUL 字节不转换）
---@field stderr  string   stderr 输出

---@class nsuda.Config
---@field executable?            string
---  Unix 默认 "sudo"。Windows 自动检测 gsudo > sudo (Win11) > 报错。
---@field noninteractive?        boolean
---  静默模式：不弹密码框、不弹确认框。默认 false。
---@field prompt?                string
---  Unix sudo 密码提示符。默认 "Password: "。
---@field smart_edit?            boolean
---  自动检测需提权文件并接管读写。默认 false。
---@field write_error_handler?   fun(ctx: nsuda.WriteCtx): boolean
---  自定义写入错误判断。默认：匹配 "E212:" + ("permission denied" | "operation not permitted")。
---@field builders?              nsuda.Builders
---  自定义提权工具 Builder。默认内置 sudo (Unix) 和 gsudo (Windows)。
```

## 4. 导出接口

```lua
---@class nsuda.Suda
local M = {}

---@param config? nsuda.Config
function M.setup(config) end

--- 提权读取文件，返回文件内容（行数组）
---@param path string
---@return string[]
function M.read(path) end

--- 提权写入内容到文件
---@param path    string
---@param lines?  string[]  默认从当前 buffer 获取
function M.write(path, lines) end

--- 提权执行命令（通过 ElevationBuilder 包装）
---@param cmd   string[]   不含提权前缀的命令
---@param opts? { stdin?: string }
---@return nsuda.SystemResult
function M.system(cmd, opts) end

--- 提权 copy 文件（平台 copy + builder.build 包装）
---@param src  string
---@param dst  string
---@return nsuda.SystemResult
function M.copy(src, dst) end
```

用户命令：
- `:SudaRead [path]` — 提权打开文件
- `:SudaWrite [path]` — 提权保存文件

## 5. ElevationBuilder 架构

### 5.1 核心思想

- **平台 copy**：独立纯函数，与提权工具无关。Unix → `dd`，Windows → `cmd /c copy /y`。
- **ElevationBuilder**：给任意 `cmd: string[]` 加上提权前缀。`build` 是免认证模式，`build_auth` 是密码模式。
- **组合**：`M.copy(src, dst)` = `M.system(builder.build(raw_copy_cmd(src, dst)))`

```lua
-- 平台 copy（纯函数，不是 Builder 字段）
local function raw_copy_cmd(src, dst)
  if is_windows then
    return { "cmd", "/c", "copy /y", src, dst }
  else
    return { "dd", "if=" .. src, "of=" .. dst, "bs=1M" }
  end
end
```

### 5.2 内置 Builder

```lua
local defaults = {
  sudo = {
    build = function(cmd)
      return { "sudo", "-n", unpack(cmd) }
    end,
    build_auth = function(cmd)
      return { "sudo", "-S", "-p", "", unpack(cmd) }
    end,
  },
  gsudo = {
    build = function(cmd)
      return { "gsudo", unpack(cmd) }
    end,
    build_auth = nil,  -- UAC 弹窗，不支持 stdin 密码
  },
}
```

### 5.3 M.copy()

```lua
function M.copy(src, dst)
  local copy_cmd = raw_copy_cmd(src, dst)
  return M.system(builder.build(copy_cmd))
end
```

### 5.4 M.system() 认证流程

```
M.system(cmd, opts):
  b = resolve_builder(config.executable)

  -- 1. 免认证尝试
  local r = vim.system(b.build(cmd), { text = true, stdin = opts.stdin }):wait()
  if r.code == 0 then return r end

  -- 2. 密码模式（仅 builder 支持 + 非静默）
  if b.build_auth and not config.noninteractive then
    local pwd = vim.fn.inputsecret(config.prompt)
    return vim.system(b.build_auth(cmd), {
      text = true,
      stdin = pwd .. "\n" .. (opts.stdin or ""),
    }):wait()
  end

  -- 3. 失败
  return r
```

## 6. API 选择：`vim.uv` / `vim.fs` 替代 `vim.fn.*`

| 用途 | 旧的 vim.fn | 新的 |
|------|------------|------|
| 文件是否存在 | `filereadable()` / `getftype()` | `vim.uv.fs_stat(path)` — nil 表示不存在 |
| 读权限 | `filereadable()` | `vim.uv.fs_access(path, "R")` |
| 写权限 | `filewritable()` | `vim.uv.fs_access(path, "W")` |
| 是否目录 | `isdirectory()` | `stat.type == "directory"` |
| 父目录 | `fnamemodify(x, ":h")` | `vim.fs.dirname(x)` |
| 绝对路径 | `fnamemodify(x, ":p")` | `vim.uv.fs_realpath(x)` |

> `vim.uv.fs_access` 在 Windows 受保护目录和 `filewritable()` 一样不可靠。E212 安全网兜底。

## 7. Smart Edit 机制

### 7.1 触发时机

`BufEnter` autocmd（`smart_edit = true`），仅普通文件 buffer。

### 7.2 排除条件

- `vim.bo.buftype ~= ""`
- 路径匹配 `%w+://` 协议
- `stat.type == "directory"`
- `vim.b.suda_checked == true`

### 7.3 判断逻辑

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

### 7.4 注册

设置 `buftype=acwrite` + 注册 buffer-local `BufWriteCmd` autocmd。

## 8. 写入流程（BufWriteCmd handler）

```
BufWriteCmd handler(target):
  1. doautocmd BufWritePre

  2. 尝试原生写入:
     vim.bo[buf].buftype = ""
     local ok, err = pcall(vim.cmd, "write")
     ok → 恢复 buftype=acwrite, nomodified, doautocmd BufWritePost ✓

     local ctx = { error = err, path = target, buf = bufnr }
     if not config.write_error_handler(ctx) then
       恢复 buftype, 原样通知 err ✗
     end

  3. 写入 tempfile:
     vim.cmd("noautocmd write " .. vim.fn.fnameescape(tempfile))

  4. 确认/静默:
     noninteractive → 跳 5
     否则 → "[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"
       Y → 5
       R → 5 + vim.fs.dirname(target) 加入白名单
       N → 保留 modified, 清 tempfile

  5. M.copy(tempfile, target):
     r.code == 0 → 恢复 buftype, nomodified, doautocmd BufWritePost ✓
     r.code != 0 → modified 不变, 通知 stderr ✗

  6. vim.uv.fs_unlink(tempfile)
```

### 8.1 默认 `write_error_handler`

```lua
function default(ctx)
  return ctx.error:match("E212:")
    and ctx.error:lower():match("permission denied|operation not permitted")
end
```

## 9. 读取流程（BufReadCmd handler）

```
BufReadCmd handler(source_path, buffer):
  1. doautocmd BufReadPre
  2. 暂存 undolevels, 禁用 swapfile/undofile
  3. tempfile = vim.fn.tempname()
  4. r = M.copy(source_path, tempfile)
     r.code != 0 → 报错 stderr, 清 tempfile, 恢复 ✗
  5. readfile(tempfile, "b"), 清旧内容, buftype=acwrite, nomodified
  6. vim.uv.fs_unlink(tempfile)
  7. doautocmd BufReadPost
```

## 10. 确认对话框

### 10.1 触发

- `write_error_handler` 返回 true
- `noninteractive = false`

### 10.2 交互

```
"[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"

Y → 提权写入
R → 提权写入 + 目录加入白名单（后续静默）
N → 取消
```

### 10.3 Remember

- 模块级局部 table，key 为目录绝对路径
- 命中白名单 → 跳过确认，直接提权
- nvim 重启清空

## 11. 平台与可执行文件检测

```
setup 自动检测 executable:

Unix → "sudo"

Windows:
  vim.fn.executable("gsudo") == 1 → "gsudo"
  vim.fn.executable("sudo") == 1  → "sudo" (Win11)
  否则 → 报错提示安装 gsudo

Builder 解析:
  config.builders[executable_name] 或内置 defaults
  找不到 → 报错
```

## 12. 配置项一览

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `executable` | string? | auto-detect | 提权可执行文件 |
| `noninteractive` | boolean | false | 静默模式 |
| `prompt` | string | "Password: " | 密码提示（Unix） |
| `smart_edit` | boolean | false | 自动接管需提权 buffer |
| `write_error_handler` | fun(ctx): bool | E212+perm 匹配 | 自定义写入错误判断 |
| `builders` | nsuda.Builders? | 内置 sudo/gsudo | 自定义提权工具 |

## 13. 不属于本设计

- FileWriteCmd（`:w suda://` 以外的写出场景）
- 密码缓存 / sudo timestamp 管理（依赖外部 sudo 配置）
- 跨平台自动测试
- 向后兼容 `vim.g`
