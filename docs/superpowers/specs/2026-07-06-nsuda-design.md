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

## 3. 导出接口

```lua
---@class nsuda.WriteCtx
---@field error  string  pcall(vim.cmd, "write") 的错误信息
---@field path   string  目标文件绝对路径
---@field buf    integer 当前 buffer number

---@class nsuda.CopyCmd
---@field src_to_dst    fun(src: string, dst: string): string[]  源 → 目标复制命令
---@field dst_from_src  fun(src: string, dst: string): string[]  从源提取内容到临时文件的命令

---@class nsuda.ElevationHandler
--- 与 copy 分离：copy 是纯平台函数，handler 封装提权工具特有的认证行为
---@field executable    string                                 可执行文件名
---@field copy          nsuda.CopyCmd                         该平台的 copy 命令
---@field args          string[]                               附加参数（如 {"-S"}）
---@field needs_password  boolean                              是否支持 stdin 密码
---@field prompt        string?                                密码提示符（needs_password 时生效）
---@field cache_check   string[]?                              缓存探测命令（如 {"-n", "true"}），nil 表示不支持

---@class nsuda.SystemResult
---@field code    integer 退出码（0 成功）
---@field stdout  string  stdout 输出（原样，NUL 字节不转换）
---@field stderr  string  stderr 输出

---@class nsuda.Config
---@field executable?            string
---  可执行文件路径。
---    Unix 默认 "sudo"
---    Windows 默认检测 gsudo > sudo (Win11) > 报错
---@field noninteractive?        boolean
---  静默模式：Unix 不弹密码框+不弹确认框。UAC 是操作系统行为无法跳过。
---  默认 false。
---@field prompt?                string
---  密码提示符。handler.needs_password=false 时忽略。默认 "Password: "。
---@field smart_edit?            boolean
---  自动检测需提权文件并接管读写。默认 false。
---@field write_error_handler?   fun(ctx: nsuda.WriteCtx): boolean
---  自定义写入错误判断。默认：匹配 "E212:" + ("permission denied" 或 "operation not permitted")。
---@field handlers?              table<string, nsuda.ElevationHandler>
---  自定义提权工具 handler。默认内置 sudo (Unix) 和 gsudo (Windows)。

---@class nsuda.Suda
local M = {}

---@param config? nsuda.Config
function M.setup(config) end

--- 提权读取文件，返回文件内容（行数组）
---@param path string
---@return string[]
function M.read(path) end

--- 提权写入内容到文件
---@param path string
---@param lines? string[]  待写入内容，默认从当前 buffer 获取
function M.write(path, lines) end

--- 提权执行命令
---@param cmd string[]  命令参数列表（不含提权可执行文件前缀）
---@param opts? { stdin?: string }
---@return nsuda.SystemResult
function M.system(cmd, opts) end

--- 提权 copy 文件（src→dst）
---@param src  string
---@param dst  string
---@return nsuda.SystemResult
function M.copy(src, dst) end
```

用户命令：
- `:SudaRead [path]` — 提权打开文件（无参数则 `edit suda://%`）
- `:SudaWrite [path]` — 提权保存文件（无参数则 `write suda://%`）

## 4. ElevationHandler 架构

### 4.1 设计思路

**两个独立维度：**

```
                    平台 copy（无提权）          提权认证（工具相关）
                    ┌─────────────────┐     ┌──────────────────────┐
  Unix              │ dd if=src of=dst │     │ sudo -S / -n         │
  Windows            │ cmd /c copy /y   │     │ gsudo (UAC)          │
  Windows Win11      │ cmd /c copy /y   │     │ sudo.exe (UAC/Win11) │
```

- **Copy 命令**：纯平台函数，与提权工具无关，所有人都用相同的复制方式
- **ElevationHandler**：封装提权工具的认证行为（密码、缓存探测、额外参数）
- **组合**：`M.system()` = `handler.executable` + `handler.args` + `cmd`

### 4.2 内置 handler

```lua
local unix_copy = {
  src_to_dst   = function(s, d) return { "dd", "if=" .. s, "of=" .. d, "bs=1M" } end,
  dst_from_src = function(s, d) return { "dd", "if=" .. s, "of=" .. d, "bs=1M" } end,
}

local win_copy = {
  src_to_dst   = function(s, d) return { "cmd", "/c", "copy /y", s, d } end,
  dst_from_src = function(s, d) return { "cmd", "/c", "copy /y", s, d } end,
}

local default_handlers = {
  sudo = {
    executable     = "sudo",
    copy           = unix_copy,
    args           = {},
    needs_password = true,
    prompt         = "Password: ",
    cache_check    = { "-n", "true" },
  },
  gsudo = {
    executable     = "gsudo",
    copy           = win_copy,
    args           = {},
    needs_password = false,
    -- prompt, cache_check 均为 nil（UAC 无 stdin 密码，无可探测缓存）
  },
}
```

### 4.3 M.system() 认证流程

```
M.system(cmd, opts):
  handler = resolve_handler(config.executable)
  args = { handler.executable } + handler.args + cmd

  1. 首次尝试（尽可能避免密码）:
     effective_args = 若 noninteractive               → args + handler.cache_check 前半段
                      若 handler.cache_check != nil   → args + handler.cache_check 前缀
                      否则                              → args
     r = vim.system(effective_args, { text = true, stdin = opts.stdin }):wait()
     if r.code == 0 → return r

  2. 尝试利用缓存（Unix sudo 场景）:
     if handler.needs_password and not noninteractive then
       cache_r = vim.system({handler.executable, unpack(handler.cache_check)},
                            { text = true }):wait()
       if cache_r.code == 0 then
         -- 缓存有效，重试不带 cache 前缀的完整命令
         return vim.system(args, { text = true, stdin = opts.stdin }):wait()
       end
     end

  3. 交互式密码（仅 handler.needs_password）:
     if not noninteractive then
       pwd = vim.fn.inputsecret(handler.prompt)
       -- sudo -S 模式：密码写到 stdin
       local stdin = pwd .. "\n" .. (opts.stdin or "")
       return vim.system(args, { text = true, stdin = stdin }):wait()
     end

  4. 返回首次结果 r（已失败）
```

### 4.4 复制 shortcut：M.copy()

```lua
--- M.copy(src, dst) = M.system(handler.copy.dst_from_src(src, dst))
function M.copy(src, dst) end
```

读/写流程中不再硬编码平台命令，统一通过 `M.copy()` 调用。

## 5. API 选择：`vim.uv` / `vim.fs` 替代 `vim.fn.*`

| 用途 | 旧的 vim.fn | 新的 |
|------|------------|------|
| 文件是否存在 | `filereadable()` / `getftype()` | `vim.uv.fs_stat(path)` — nil 表示不存在 |
| 读权限 | `filereadable()` | `vim.uv.fs_access(path, "R")` |
| 写权限 | `filewritable()` | `vim.uv.fs_access(path, "W")` |
| 是否目录 | `isdirectory()` | `type == "directory"` from `vim.uv.fs_stat(path)` |
| 父目录 | `fnamemodify(x, ":h")` | `vim.fs.dirname(x)` |
| 绝对路径 | `fnamemodify(x, ":p")` | `vim.uv.fs_realpath(x)` 或 `vim.fs.normalize(...)` |

注意事项：
- `vim.uv.fs_access` 在 Windows 受保护目录（`C:\Program Files`）和 `filewritable()` 一样不可靠。E212 安全网负责兜底。

## 6. Smart Edit 机制

### 6.1 触发时机

`BufEnter` autocmd（`smart_edit = true`），仅普通文件 buffer。

### 6.2 排除条件

- `vim.bo.buftype ~= ""`
- 路径匹配 `%w+://` 协议
- `stat.type == "directory"`
- `vim.b.suda_checked == true`

### 6.3 判断逻辑

```
stat = vim.uv.fs_stat(path)

├─ stat 存在 + type=="file":
│   ├─ vim.uv.fs_access(path, "W") → 不干预
│   ├─ vim.uv.fs_access(path, "W") == false → buftype=acwrite + BufWriteCmd
│   └─ vim.uv.fs_access(path, "R") == false → suda://
│
├─ stat 不存在:
│    逐级向上查父目录:
│      parent_stat = vim.uv.fs_stat(parent)
│      ├─ type=="directory" + fs_access(parent, "W") → 不干预
│      ├─ type=="directory" + not fs_access(parent, "W") → buftype=acwrite
│      └─ nil → 继续向上（找不到存在的目录 → 不干预）
└─ 其他 → 不干预
```

### 6.4 BufWriteCmd 注册

对需要提权的 buffer，设置 `buftype=acwrite` + 注册 buffer-local `BufWriteCmd` autocmd。

## 7. 写入流程（BufWriteCmd handler）

```
BufWriteCmd handler(target):
  1. doautocmd BufWritePre

  2. 尝试原生写入:
     vim.bo[buf].buftype = ""
     local ok, err = pcall(vim.cmd, "write")
     ok → 恢复 buftype=acwrite, set nomodified, doautocmd BufWritePost ✓

     ctx = { error = err, path = target, buf = bufnr }
     if not write_error_handler(ctx) → 恢复 buftype, 原样通知 err ✗

  3. 写入 tempfile:
     vim.cmd("noautocmd write " .. vim.fn.fnameescape(tempfile))

  4. 确认/静默:
     noninteractive → 跳 5
     否则 → "[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"
       Y → 5
       R → 5 + 目录加入 in-memory 白名单
       N → modified 不变, 清 tempfile

  5. copy tempfile → target:
     r = M.copy(tempfile, target)
     r.code == 0 → 恢复 buftype, nomodified, doautocmd BufWritePost ✓
     r.code != 0 → modified 不变, 通知 stderr ✗

  6. vim.uv.fs_unlink(tempfile)
```

### 7.1 默认 `write_error_handler`

```lua
function default(ctx)
  return ctx.error:match("E212:")
    and ctx.error:lower():match("permission denied|operation not permitted")
end
```

## 8. 读取流程（BufReadCmd handler）

```
BufReadCmd handler(source_path, buffer):
  1. doautocmd BufReadPre
  2. 暂存 undolevels, 禁用 swapfile/undofile
  3. tempfile = vim.fn.tempname()
  4. r = M.copy(source_path, tempfile)
  5. r.code != 0 → 报错 stderr, 清 tempfile, 恢复 ✗
  6. r.code == 0 → readfile(tempfile, "b"), 清旧内容, buftype=acwrite, nomodified
  7. vim.uv.fs_unlink(tempfile)
  8. doautocmd BufReadPost
```

## 9. 确认对话框

### 9.1 触发条件

- `write_error_handler` 返回 true
- `noninteractive = false`

### 9.2 交互

```
"[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"

Y → 提权写入
R → 提权写入 + vim.fs.dirname(path) 记入白名单
N → 取消
```

### 9.3 Remember

- 模块级局部 table，key 为目录绝对路径
- 命中白名单 → 跳过确认框，直接提权
- nvim 重启清空

## 10. 平台与可执行文件检测

```
setup 自动检测 executable:

Unix:
  → "sudo"

Windows:
  vim.fn.executable("gsudo") == 1 → "gsudo"
  vim.fn.executable("sudo") == 1  → "sudo" (Win11)
  否则 → 报错提示安装 gsudo

handler 选择:
  config.handlers[executable] 或内置 defaults
  找不到 handler → 报错
```

## 11. 配置项一览

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `executable` | string? | auto-detect | 提权可执行文件 |
| `noninteractive` | boolean | false | 静默模式 |
| `prompt` | string | "Password: " | 密码提示（Unix） |
| `smart_edit` | boolean | false | 自动接管需提权 buffer |
| `write_error_handler` | fun(ctx): bool | E212+perm 匹配 | 自定义写入错误判断 |
| `handlers` | table<string, Handler>? | 内置 sudo/gsudo | 自定义提权工具 |

## 12. 不属于本设计

- FileWriteCmd（`:w suda://` 以外的写出场景）
- 密码缓存 / sudo timestamp 管理（依赖外部 sudo 配置）
- 跨平台自动测试
- 向后兼容 `vim.g`
