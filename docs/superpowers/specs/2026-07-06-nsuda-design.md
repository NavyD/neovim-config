# nsuda — Neovim sudo plugin, Lua rewrite of suda.vim

## 1. 背景

suda.vim 是一个 Vim/Neovim 插件，通过 `sudo` 命令实现提权读写文件。核心机制：注册 `suda://` 协议，拦截 `BufReadCmd`/`BufWriteCmd` 自动命令。在 Windows 上存在两个重大 bug：

1. **tee.exe 挂起 + 源文件被清空**：`SudaWrite` 执行 `sudo tee target`，tee.exe 弹出窗口不退出，导致写入流程卡死，源文件可能被截断
2. **gsudo + 密码提示冲突**：设置 `g:suda#executable = 'gsudo'` 后，suda.vim 仍尝试 `inputsecret()` 密码输入，但 gsudo 走 UAC 机制无需密码，导致交互混乱，文件保存失败

nsuda 是 suda.vim 的 Lua 重写版，优先解决 Windows bug，同时使用 Neovim 0.12+ `vim.system()` API 实现。

## 2. 设计目标

- **独立插件**：`lua/suda.lua` 单文件，`setup()` 风格配置
- **不一对一翻译**：使用 Neovim 原生 Lua API，不用 vimscript 遗留方式
- **Windows first**：从根源解决 suda.vim 的两个 bug
- **最小依赖**：无第三方 Lua 库、无外部工具（gsudo 除外）

## 3. 导出接口

```lua
---@class nsuda.Config
---@field executable? string  提权可执行文件路径，默认 auto-detect（Unix=sudo, Windows 检查 gsudo）
---@field noninteractive? boolean  静默提权，不弹密码框也不弹确认框，默认 false
---@field prompt? string  Unix sudo 密码提示符，默认 "Password: "
---@field smart_edit? boolean  自动检测需提权的文件并接管读写，默认 false

---@class nsuda.Suda
local M = {}

---@param config? nsuda.Config
function M.setup(config) end

--- 提权读取文件，返回文件行列表
---@param path string
---@return string[]
function M.read(path) end

--- 提权写入当前 buffer 内容到文件
---@param path string
---@param lines? string[]  待写入内容，默认从当前 buffer 获取
function M.write(path, lines) end

--- 提权执行任意命令，模拟 systemlist() 行为
---@param cmd string[]  命令列表（不含 "sudo" 前缀）
---@param input? string  stdin 输入
---@return string[]  命令输出的行列表
function M.system(cmd, input) end

--- 提权执行任意命令，返回 raw 输出字符串
---@param cmd string[]
---@param input? string
---@return string
function M.system_raw(cmd, input) end
```

用户命令：
- `:SudaRead [path]` — 提权打开文件
- `:SudaWrite [path]` — 提权保存文件

## 4. Smart Edit 机制

### 4.1 触发时机

`BufEnter` autocmd（当 `smart_edit = true`），仅对普通文件 buffer 生效。

### 4.2 排除条件

- `buftype != ""`（terminal/help/quickfix 等）
- 带协议前缀（`oil://`、`fugitive://`、`suda://` 等）
- 文件是目录
- 已检查过的 buffer（`vim.b.suda_checked = true`）

### 4.3 判断逻辑

```
buffer 路径 path:
  ├─ 文件存在 + 可读 + filewritable(path) == 1 → 普通 buffer，不干预
  ├─ 文件存在 + 可读 + filewritable(path) == 0 → 设 buftype=acwrite + 注册 BufWriteCmd
  ├─ 文件存在 + 不可读 → 切 suda:// 协议（BufReadCmd 走提权读）
  ├─ 文件不存在 + 父目录不可写 → 设 buftype=acwrite + 注册 BufWriteCmd
  └─ 文件不存在 + 父目录可写 → 普通 buffer，不干预
```

父目录不可写检测（文件不存在时）：
- 从 path 出发逐级向上，检查 `filewritable(parent)`
- 只要找到 `filewritable(parent) == 2`（目录可写），就认为正常
- 如找到不存在的目录但 `isdirectory() == true` 且 `filereadable() == 0`，也跳出（父目录不存在的情况不干预）

### 4.4 BufWriteCmd 注册方式

对判定为需提权的 buffer，设置 `buftype=acwrite` 并注册 `BufWriteCmd` 为该 buffer 专属 autocmd（使用 `<buffer>` pattern）。

**不**对所有 buffer 全量注册 BufWriteCmd——只对风险 buffer 注册。

## 5. 写入流程（BufWriteCmd handler）

### 5.1 核心流程

```
BufWriteCmd handler(target):
  1. 触发 BufWritePre（noautocmd 模式没触发，要显式 doautocmd）

  2. 先尝试原生写入:
     vim.bo[buf].buftype = ""
     local ok, err = pcall(vim.cmd, "write")
     成功 → 恢复 buftype=acwrite, set nomodified, 触发 BufWritePost ✓
     
     E212 + permission denied / operation not permitted → 进入 3
     其他错误 → 恢复 buftype, 原样报错, 触发 BufWritePost ✗

  3. 写入 tempfile:
     vim.cmd.write({vim.fn.fnameescape(tempfile)})
     使用 Neovim 原生 :write 保证编码/BOM/fileformat 正确处理

  4. 确认/静默:
     noninteractive=true → 静默执行 5
     否则 → 弹出确认对话框，选项:
       [Y] 提权保存 (本次)
       [N] 取消
       [R] 提权保存 + 记住（in-memory，nvim 重启后重置）

  5. 提权复制:
     若确认取消 → 保留 modified, 报错 ✗
     Windows: vim.system({"gsudo", "cmd", "/c", "copy /y", tempfile, target})
     Unix:    vim.system({"sudo", "dd", "if="..tempfile, "of="..target, "bs=1M"})
     成功 → 恢复 buftype, set nomodified, 触发 BufWritePost ✓
     失败 → 保留 modified, 报错 ✗

  6. 清理 tempfile
```

### 5.2 关键技术决策

- **不用 stdin pipe**：通过 tempfile 中转，提权进程只做文件复制（`copy`/`dd`），不接触文件内容。彻底避免 suda.vim 的 tee+stdin 挂起
- **二进制安全**：`:write tempfile` → 提权 `copy`/`dd` tempfile → target。NUL 字节不经 stdout，全程二进制安全
- **先原生写后兜底**：对可写文件零开销，不可写时自动 fallback

### 5.3 E212 错误匹配

```lua
local ok, err = pcall(vim.cmd, "write")
if not ok then
  if err:match("E212:") and err:lower():match("permission denied|operation not permitted") then
    -- 提权流程
  end
end
```

Linux 报 `permission denied`，Windows 报 `operation not permitted`。

## 6. 读取流程（BufReadCmd handler）

### 6.1 核心流程

```
BufReadCmd handler(source_path, buffer):
  1. 触发 BufReadPre
  2. 暂存 undolevels, 禁用 swapfile/undofile
  3. 创建 tempfile
  4. 提权复制:
     Windows: gsudo cmd /c "copy /y" source_path tempfile
     Unix:    sudo dd if=source_path of=tempfile bs=1M
  5. 失败 → 报错, 清理
     成功 → :read ++edit tempfile (或 delete 旧内容后 readfile(tempfile, "b"))
  6. 设置 buftype=acwrite, nomodified
  7. filetype detect
  8. 清理 tempfile
  9. 触发 BufReadPost
```

### 6.2 关键技术决策

- **不用 cat/type pipe**：suda.vim 用 `sudo cat | systemlist` 通过 stdout 获取内容，NUL → NL 映射损坏二进制文件。nsuda 用 copy/dd 到 tempfile，再 `readfile` 加载，全程二进制安全
- **"b" 模式**：`readfile(tempfile, "b")` 保留 NUL 字节，逐行加载到 buffer

## 7. 通用 sudo 命令 API

### 7.1 函数签名

```lua
--- 执行提权命令，返回类似 systemlist() 的输出
function M.system(cmd, input) end

--- 执行提权命令，返回 raw stdout 字符串
function M.system_raw(cmd, input) end
```

### 7.2 密码交互逻辑

```
executable == "sudo" (Unix):
  noninteractive 已启用 → 直接尝试 sudo -n cmd
  否则:
    1. sudo -n true (测试 timestamp 有效)
       成功 → sudo cmd (带 timestamp 免密码)
       失败 → inputsecret("Password: ") → sudo -S cmd

executable == "gsudo" (Windows):
  gsudo 走 UAC 弹窗，不需要 stdin 密码
  noninteractive 已启用 → 直接 gsudo cmd
  否则 → gsudo cmd (让 gsudo 自己处理 UAC 弹窗)

executable == 其他:
  不处理密码，直接执行
```

### 7.3 返回值一致性

`system()` 返回 `string[]`（按行分割），`system_raw()` 返回 `string`。二进制安全——NUL 字节不转换。

## 8. 确认对话框设计

### 8.1 触发条件

- BufWriteCmd handler 中，`pcall(write)` 返回 E212 权限错误
- `noninteractive = false`

### 8.2 交互逻辑

```
"[nsuda] Elevate and save <filename>? [Y]es [R]emember [N]o"

Y → 执行提权写入
R → 执行提权写入 + 将当前目录加入 in-memory 白名单（后续静默）
N → 取消，保留 modified 状态
```

### 8.3 Remember 机制

- 白名单存储在 Lua 模块级 table 中（`vim.g` 或模块局部变量）
- 以**目录**为粒度，匹配前缀：`file:gsub("[\\/][^\\/]*$", "")`
- nvim 重启后清空（in-memory only，不持久化）

## 9. 平台适配

### 9.1 可执行文件检测

```lua
setup 时:
  if executable 未指定:
    Unix:  "sudo"
    Windows: vim.fn.executable("gsudo") == 1 ? "gsudo" : 报错提示安装
```

### 9.2 路径处理

- Windows 反斜杠路径正常通过 `vf.system()` 传递给 `cmd /c` 或 `powershell`
- `fnameescape()` 用于 vim.cmd 调用，`vp.shellesc()` 用于外部 shell
- tempfile 使用 `vim.fn.tempname()` 或 `os.tmpname()`

### 9.3 用户安装提示

```
"[nsuda] gsudo not found. Install from https://github.com/gerardog/gsudo"
```

## 10. 配置项一览

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `executable` | string? | auto-detect | 提权可执行文件 |
| `noninteractive` | boolean | false | 静默模式，不提示密码/确认 |
| `prompt` | string | "Password: " | 密码提示文本 |
| `smart_edit` | boolean | false | 自动接管需提权的 buffer |

向后兼容 `vim.g` 变量（Deprecated，仅过渡期支持）：
- `vim.g.suda_smart_edit` → `smart_edit`
- `vim.g["suda#noninteractive"]` → `noninteractive`
- `vim.g["suda#executable"]` → `executable`
- `vim.g["suda#prompt"]` → `prompt`

## 11. 不属于本设计的

- FileWriteCmd（`:w suda://` 以外的写出场景）— 后续迭代
- 密码缓存 / sudo timestamp 管理 — 依赖外部 sudo 配置
- `suda#systemlist()` 公共 API — 用 `system()` 代替
- 跨平台二进制安全测试 — 在实现阶段覆盖

## 12. 纠错清单

- [x] 是否只有 E212 + permission denied 才触发提权 — 是
- [x] 是否避免 stdin pipe 免 tee hang — 是（tempfile + copy/dd）
- [x] 二进制安全 — 是（不经过 stdout pipe）
- [x] gsudo 不弹密码框 — 是（跳过 inputsecret() 逻辑）
- [x] 单文件 — 是
- [x] confirm 对话框不支线 — 通过 in-memory remember 实现
