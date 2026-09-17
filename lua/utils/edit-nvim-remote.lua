-- edit-nvim-remote.lua
-- 用法: nvim -l edit-nvim-remote.lua -- <filename> [line]
-- 行为对齐 lazygit nvim-remote 预设
-- https://github.com/jesseduffield/lazygit/blob/71d3e7dfa5f9278172013bfa1bb83d60d155436a/pkg/config/editor_presets.go#L68

local function fail(msg)
  -- vim.notify(msg, vim.log.levels.ERROR)
  -- 不加载 nvim 插件时 notify 可能没有接收方
  io.stderr:write("[edit-remote] " .. msg .. "\n")
  os.exit(1)
end

-- 1. 解析参数（跳过 "--"）
local args = {}
for i = 1, #arg do
  if arg[i] ~= "--" then
    args[#args + 1] = arg[i]
  end
end
local filename = args[1]
local line = args[2] and tonumber(args[2]) or nil

if not filename then
  fail("No filename provided")
end
-- 转绝对路径，消除父 nvim cwd 与 lazygit cwd 不一致的歧义
filename = vim.fn.fnamemodify(filename, ":p")

local nvim_server = vim.env.NVIM

-- 2. 无 $NVIM：挂起，前台启动新 nvim，等编辑器退出
if not nvim_server or nvim_server == "" then
  local cmd = { "nvim" }
  if line then
    cmd[#cmd + 1] = "+" .. line
  end
  cmd[#cmd + 1] = "--"
  cmd[#cmd + 1] = filename
  -- 前台等待，行为等价于 suspend = true

  -- local ok = vim.fn.jobwait({ vim.fn.jobstart(cmd, { pty = true }) })[1]
  -- vim.system() 是 jobstart 在非交互场景下的现代替代品，官方也推荐优先使用它
  -- 前提是不需要 pty。你的 nvim -l 脚本要前台拉起一个交互式 nvim 并等它退出，
  -- pty = true 是不可绕过的，所以只能继续用 jobstart + jobwait。
  local id = vim.fn.jobstart(cmd, { pty = true })
  -- 失败的显式处理
  if id <= 0 then
    fail("Failed to start nvim: " .. table.concat(cmd, " "))
  end
  local ok = vim.fn.jobwait({ id })[1]
  os.exit(ok == 0 and 0 or 1)
end

-- 3. 有 $NVIM：RPC 通信，异步，行为等价于 suspend = false
local ok, chan = pcall(vim.fn.sockconnect, "pipe", nvim_server, { rpc = true })
if not ok or chan <= 0 then
  fail("Failed to connect to parent Neovim: " .. tostring(nvim_server))
end

local function rpc(method, ...)
  local ok2, err = pcall(vim.rpcrequest, chan, method, ...)
  if not ok2 then
    vim.fn.chanclose(chan)
    fail("RPC failed: " .. tostring(err))
  end
end

-- 3.1 发送按键 "q"（对齐 --remote-send "q"）
rpc("nvim_input", "q")

-- 3.2 在新 tab 打开文件（对齐 --remote-tab）
-- local escaped = vim.fn.fnameescape(filename)
-- rpc("nvim_command", "tabedit " .. escaped)
-- fnameescape 不处理空格，:tabedit a b.txt 被拆成两个文件。
rpc("nvim_cmd", { cmd = "tabedit", args = { filename } }, {})

-- 3.3 跳转到指定行（对齐 --remote-send ":line<CR>"）
if line then
  rpc("nvim_input", ":" .. line .. "\r")
end

vim.fn.chanclose(chan)
os.exit(0)
