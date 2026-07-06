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
---@class nsuda.Config
---@field executable? string
---  提权可执行文件路径。
---     Unix 默认 "sudo"
---     Windows 默认检测 gsudo > sudo (Win11 sudo.exe) > 报错
---@field noninteractive? boolean
---  静默模式：不弹密码框、不弹确认框（UAC 弹窗是操作系统行为，无法跳过）。
---  默认 false。
---@field prompt? string
---  Unix sudo 密码提示符，默认 "Password: "。
---  Windows 上忽略（UAC 机制无 stdin 密码）。
---@field smart_edit? boolean
---  自动检测需提权的文件并接管读写。默认 false。
---@field write_error_handler? fun(err_msg: string, ctx: nsuda.WriteCtx): boolean
---  自定义写入错误判断函数。传入 pcall(write) 的错误信息及上下文，
---  返回 true 表示该错误应进入提权流程，false 表示原样报错。
---  默认实现：匹配 "E212:" + ("permission denied" 或 "operation not permitted")。

---@class nsuda.WriteCtx
---@field path string  目标文件绝对路径
---@field buf integer  当前 buffer number
---@field range? string  命令行 range（如 "'[,'']"）

---@class nsuda.SystemResult
---@field code  integer  退出码（0 成功）
---@field stdout  string  stdout 输出（原样，NUL 字节不转换）
---@field stderr  string  stderr 输出

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
---@param lines? string[]  待写入内容，默认从当前 buffer 获取全部行
function M.write(path, lines) end

--- 提权执行命令
---@param cmd string[]  命令参数列表（不含提权可执行文件前缀）
---@param opts? { stdin?: string }  可选 stdin
---@return nsuda.SystemResult
function M.system(cmd, opts) end
```

用户命令：
- `:SudaRead [path]` — 提权打开文件（若传入 path 则 `edit suda://path`，否则 `edit suda://%`）
- `:SudaWrite [path]` — 提权保存文件（若传入 path 则 `write suda://path`，否则 `write suda://%`）

## 4. API 选择：`vim.uv` / `vim.fs` 替代 `vim.fn.*`

文件检测全部使用 Neovim 原生 Lua API，不使用 `vim.fn.filereadable()` / `vim.fn.filewritable()` 等：

| 用途 | 旧的 vim.fn | 新的 |
|------|------------|------|
| 文件是否存在 / stat 信息 | `filereadable()` / `getftype()` | `vim.uv.fs_stat(path)` — 返回 nil 如果不存在 |
| 读权限检查 | `filereadable()` | `vim.uv.fs_access(path, "R")` |
| 写权限检查 | `filewritable()` | `vim.uv.fs_access(path, "W")` |
| 是否目录 | `isdirectory()` | 检查 `vim.uv.fs_stat(path).type == "directory"` |
| 路径拼接 | `fnamemodify(x, ":h")` | `vim.fs.dirname(x)` |
| 绝对路径 | `fnamemodify(x, ":p")` | `vim.fs.normalize(vim.fn.fnamemodify(x, ":p"))` 或 `vim.uv.fs_realpath()` |

注意事项：
- `vim.uv.fs_access` 在 Windows 上对受保护目录（如 `C:\Program Files`）的 W 权限检测和 `filewritable()` 同样不可靠。因此仍然依赖写入时的 E212 安全网。
- `vim.uv.fs_stat` 比 `filereadable()` + `getftype()` 一次调用获取更多信息，减少系统调用。

## 5. Smart Edit 机制

### 5.1 触发时机

`BufEnter` autocmd（当 `smart_edit = true`），仅对普通文件 buffer 生效。

### 5.2 排除条件

- `vim.bo.buftype ~= ""`（terminal/help/quickfix 等）
- 路径匹配 protocol 前缀 pattern `%w+://`（`oil://`、`fugitive://`、`suda://` 等）
- `vim.uv.fs_stat(path).type == "directory"`
- 已检查过的 buffer（`vim.b.suda_checked == true`）

### 5.3 判断逻辑

```
stat = vim.uv.fs_stat(path)

├─ stat 存在 + type=="file" + vim.uv.fs_access(path, "W") → 普通 buffer，不干预
├─ stat 存在 + type=="file" + not vim.uv.fs_access(path, "W") → 设 buftype=acwrite + 注册 BufWriteCmd
├─ stat 存在 + type=="file" + not vim.uv.fs_access(path, "R") → 切 suda:// 协议
├─ stat 不存在:
│   从 path 出发逐级 vim.fs.dirname() 向上检查:
│     parent_stat = vim.uv.fs_stat(parent)
│     ├─ parent_stat 存在 + type=="directory" + vim.uv.fs_access(parent, "W") → 正常 buffer
│     └─ parent_stat 存在 + type=="directory" + not vim.uv.fs_access(parent, "W") → 设 buftype=acwrite
│       (找到存在且不可写目录，说明需提权；一直找不到存在的目录说明路径整体不存在，不干预)
└─ 其他 → 不干预
```

### 5.4 BufWriteCmd 注册方式

对判定为需提权的 buffer，设置 `buftype=acwrite` 并注册 `BufWriteCmd` 为该 buffer 专属 autocmd（使用 `buffer` option 限定范围）。

## 6. 写入流程（BufWriteCmd handler）

### 6.1 核心流程

```
BufWriteCmd handler(target):
  1. doautocmd BufWritePre（需显式触发）

  2. 尝试原生写入:
     vim.bo[buf].buftype = ""
     local ok, err = pcall(vim.cmd, "write")
     ok → 恢复 buftype=acwrite, set nomodified, doautocmd BufWritePost ✓

     调用 config.write_error_handler(err, ctx):
       true → 进入 3（提权流程）
       false → 恢复 buftype, 原样通知 err, doautocmd BufWritePost ✗

  3. 写入 tempfile:
     vim.cmd("noautocmd write " .. vim.fn.fnameescape(tempfile))
     使用 Neovim 原生 :write 保证编码/BOM/fileformat/换行符正确处理

  4. 确认/静默:
     config.noninteractive → 静默执行 5
     否则 → 弹出确认对话框 "[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o":
       Y → 执行 5
       R → 执行 5 + 将文件所在目录加入 in-memory 白名单
       N → 保留 modified, 清理 tempfile, 通知用户取消

  5. 提权复制:
     ┌─ 通过 M.system() 执行 ─────────────────────────────────┐
     │ Windows: {executable, "cmd", "/c", "copy /y", tempfile, target}    │
     │ Unix:    {executable, "dd", "if="..tempfile, "of="..target, "bs=1M"}│
     └────────────────────────────────────────────────────────┘
     返回 code==0 → 恢复 buftype, set nomodified, doautocmd BufWritePost ✓
     code!=0 → 保留 modified, 通知 stderr, doautocmd BufWritePost ✗

  6. 清理 tempfile: vim.uv.fs_unlink(tempfile)
```

### 6.2 默认 `write_error_handler`

```lua
function default_write_error_handler(err, ctx)
  return err:match("E212:") and err:lower():match("permission denied|operation not permitted")
end
```

用户可以替换为自己的逻辑，例如根据 `ctx.path` 匹配特定路径规则。

### 6.3 关键技术决策

- **不用 stdin pipe**：tempfile 中转，提权进程只做文件复制（`copy`/`dd`），不接触文件内容。彻底避免 tee+stdin 挂起
- **二进制安全**：`:write tempfile` → 提权 `copy`/`dd` tempfile → target。NUL 字节不经 stdout pipe
- **先原生写后兜底**：可写文件零开销，不可写时自动 fallback

## 7. 读取流程（BufReadCmd handler）

### 7.1 核心流程

```
BufReadCmd handler(source_path, buffer):
  1. doautocmd BufReadPre
  2. 暂存 undolevels, 禁用 swapfile/undofile
  3. 创建 tempfile
  4. 提权复制到 tempfile:
     ┌─ M.system() ─────────────────────────────────────┐
     │ Windows: {executable, "cmd", "/c", "copy /y", source_path, tempfile}│
     │ Unix:    {executable, "dd", "if="..source_path, "of="..tempfile, "bs=1M"}│
     └──────────────────────────────────────────────────┘
  5. code!=0 → 报错 stderr, 清理, 恢复 ✗
     code==0 → readfile(tempfile, "b") 加载到 buffer, 清理旧内容
  6. buftype=acwrite, nomodified, filetype detect
  7. 清理 tempfile
  8. doautocmd BufReadPost
```

### 7.2 关键技术决策

- **不用 cat/type pipe**：suda.vim 用 `sudo cat | systemlist` 通过 stdout，NUL → NL 损坏二进制文件。nsuda 用 copy/dd 到 tempfile，再 `readfile(tempfile, "b")` 加载
- **"b" 模式**：`readfile(path, "b")` 保留 NUL 字节不转 NL

## 8. `M.system()` API

### 8.1 函数签名

```lua
---@param cmd string[]  命令参数列表（不含提权可执行文件前缀）
---@param opts? { stdin?: string }
---@return nsuda.SystemResult { code: integer, stdout: string, stderr: string }
function M.system(cmd, opts) end
```

### 8.2 实现

```lua
function M.system(cmd, opts)
  opts = opts or {}
  local args = { config.executable }
  vim.list_extend(args, build_elevation_args())  -- -S -p 等
  vim.list_extend(args, cmd)
  local sys = vim.system(args, { text = true, stdin = opts.stdin })
  return sys:wait()
end
```

不依赖 `vim.v.shell_error`，返回结构清晰的 Lua table。

### 8.3 密码交互逻辑

区分平台和可执行文件类型：

```
vim.uv.os_uname().sysname 返回平台:

Unix (Linux/macOS):
  executable == "sudo":
    noninteractive → sudo -n cmd
    否则:
      1. sudo -n true (测试 timestamp)
         成功 → sudo cmd (免密码)
         失败 → inputsecret(prompt) → sudo -S cmd
  executable == "doas" 等:
    同样逻辑，根据参数约定调整（-n 等）

Windows:
  所有可执行文件 (gsudo, sudo.exe):
    UAC 弹窗是操作系统行为，无 stdin 密码
    noninteractive 对密码无意义（无法跳过 UAC）
    直接执行: {executable} cmd ...
  密码提示 prompt 配置项在 Windows 上忽略
```

## 9. 确认对话框设计

### 9.1 触发条件

- BufWriteCmd handler 中 `write_error_handler` 返回 true
- `config.noninteractive = false`

### 9.2 交互

```
"[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"

Y → 执行提权写入
R → 执行提权写入 + 将目标文件所在目录加入 in-memory 白名单
N → 取消，保留 modified 状态
```

### 9.3 Remember 机制

- 白名单是模块级局部 table，key 为目录路径（通过 `vim.fs.dirname(target)` 获取）
- 后续同一目录下的文件触发 `write_error_handler` 时，白名单命中则直接静默提权（不弹确认框）
- nvim 重启后清空（in-memory only）

## 10. 平台适配

### 10.1 可执行文件检测

```
setup 未指定 executable 时:

vim.uv.os_uname().sysname 不是 "Windows_NT":
  → executable = "sudo"

vim.uv.os_uname().sysname == "Windows_NT":
  if vim.fn.executable("gsudo") == 1  → "gsudo"
  elseif vim.fn.executable("sudo") == 1  → "sudo"  (Win11 sudo.exe)
  else → 报错:
    "[nsuda] No elevation tool found. Install gsudo (https://github.com/gerardog/gsudo)
     or enable sudo on Windows 11."
```

### 10.2 路径处理

- tempfile: `vim.fn.tempname()` 或 `os.tmpname()`
- `vim.fn.fnameescape(path)` 用于传递给 `vim.cmd` 的命令
- `vim.system()` 的 args 直接传字符串数组，由 Neovim 处理转义

### 10.3 平台特有命令

| 场景 | Unix | Windows |
|------|------|---------|
| 提权复制目标 | `dd if=tmp of=dst bs=1M` | `cmd /c copy /y tmp dst` |
| 提权复制源 | `dd if=src of=tmp bs=1M` | `cmd /c copy /y src tmp` |
| 密码模式 | `sudo -S` (stdin) | 无 (UAC) |
| 非交互模式 | `sudo -n` | 无影响 |
| Timestamp 测试 | `sudo -n true` | 不适用 |

## 11. 配置项一览

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `executable` | string? | auto-detect | 提权可执行文件 |
| `noninteractive` | boolean | false | 静默模式：Unix 不弹密码框、不弹确认框（UAC 无法跳过） |
| `prompt` | string | "Password: " | Unix sudo 密码提示（Windows 忽略） |
| `smart_edit` | boolean | false | 自动接管需提权的 buffer |
| `write_error_handler` | function? | 默认 E212+perm 匹配 | 自定义写入错误判断 |

## 12. 不属于本设计的

- FileWriteCmd（`:w suda://` 以外的写出场景）— 后续迭代
- 密码缓存 / sudo timestamp 管理 — 依赖外部 sudo 配置
- 跨平台自动测试 — 实现阶段覆盖
- 向后兼容 `vim.g` 旧变量
