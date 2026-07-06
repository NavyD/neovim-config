-- lua/suda.lua
-- vim-suda rewritten in Lua, using only vim.system (Neovim 0.12+).
-- Maintains original behavior, adds intercept_write for Windows E212 fix.

local M = {}

M.config = {
  executable = "sudo",
  prompt = "Password: ",
  noninteractive = false,
  smart_edit = false,
  intercept_write = true,
  extra_args = nil,
}

----------------------------------------------------------------------
-- Utility
----------------------------------------------------------------------

local function strip_prefix(str)
  return (str:gsub("^(suda://)+", ""))
end

local function build_cmd(executable, is_sudo, opts, extra, cmd)
  local args = { executable }
  if extra and #extra > 0 then
    for _, e in ipairs(extra) do
      args[#args + 1] = e
    end
  elseif is_sudo then
    for _, o in ipairs(opts) do
      args[#args + 1] = o
    end
    args[#args + 1] = "--"
  end
  for _, c in ipairs(cmd) do
    args[#args + 1] = c
  end
  return args
end

-- Core systemlist using vim.system (requires Neovim 0.12+)
---@param cmd string[]
---@param input nil|true|string|string[]
function M.systemlist(cmd, input)
  local opts = {}
  if input then
    opts.text = input
  end
  local obj = vim.system(cmd, opts)
  local result = obj:wait()
  vim.v.shell_error = result.code

  -- Emulate systemlist: NUL -> NL, then split by NL
  local output = (result.stdout or ""):gsub("\0", "\n")
  return vim.split(output, "\n", { plain = true, trimempty = false })
end

-- Emulate system() behavior
function M.system(cmd, input)
  local output = M.systemlist(cmd, input)
  local result = {}
  for _, line in ipairs(output) do
    -- Replace any NL (originally NUL) with SOH
    local s, _ = line:gsub("\n", "\1")
    table.insert(result, s)
  end
  return table.concat(result, "\n")
end

-- Execute a command with full password/retry logic (as in original)
function M.exec_with_suda(cmd, input)
  local is_sudo = M.config.executable == "sudo"
  local noninteractive = M.config.noninteractive
  local extra = M.config.extra_args

  local opts = {}
  if extra and #extra > 0 then
    -- skip default opts
  elseif noninteractive or vim.fn.has("win32") == 1 then
    -- no password-related flags
  else
    opts = { "-p", "", "-n" }
  end

  local full_cmd = build_cmd(M.config.executable, is_sudo, opts, extra, cmd)
  if vim.o.verbose > 0 then
    vim.api.nvim_echo({ { "[suda] " .. table.concat(full_cmd, " ") } }, true, {})
  end

  local result = M.systemlist(full_cmd, input)
  if vim.v.shell_error == 0 then
    return result
  end

  if noninteractive then
    return result
  end

  if not is_sudo then
    return result
  end

  -- Interactive sudo: check timestamp
  local test_cmd = build_cmd("sudo", true, { "-n" }, nil, { "true" })
  M.systemlist(test_cmd)
  if vim.v.shell_error == 0 then
    local retry_cmd = build_cmd("sudo", true, {}, nil, cmd)
    if vim.o.verbose > 0 then
      vim.api.nvim_echo({ { "[suda] " .. table.concat(retry_cmd, " ") } }, true, {})
    end
    return M.systemlist(retry_cmd, input)
  end

  -- Ask for password
  vim.fn.inputsave()
  vim.cmd("redraw")
  local password = vim.fn.inputsecret(M.config.prompt)
  vim.fn.inputrestore()

  local pass_cmd = build_cmd("sudo", true, { "-p", "", "-S" }, nil, cmd)
  if vim.o.verbose > 0 then
    vim.api.nvim_echo({ { "[suda] " .. table.concat(pass_cmd, " ") } }, true, {})
  end
  local stdin = password .. "\n"
  if input then
    stdin = stdin .. input
  end
  return M.systemlist(pass_cmd, stdin)
end

----------------------------------------------------------------------
-- Read / Write
----------------------------------------------------------------------

function M.read(expr, opts)
  local path = strip_prefix(expr)
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  opts = opts or {}
  local cmdarg = opts.cmdarg or vim.v.cmdarg
  local range = opts.range or ""

  if vim.fn.filereadable(path) == 1 then
    local cmd = string.format("%sread %s %s", range, cmdarg, vim.fn.fnameescape(path))
    return vim.fn.execute(cmd):gsub("^\r?\n", "")
  end

  local temp = vim.fn.tempname()
  local ok, ret = pcall(function()
    local lines = M.exec_with_suda({ "cat", path })
    if vim.v.shell_error ~= 0 then
      error("Cannot read " .. path)
    end
    vim.fn.writefile(lines, temp, "b")
    local read_cmd = string.format("%sread %s %s", range, cmdarg, vim.fn.fnameescape(temp))
    local msg = vim.fn.execute(read_cmd):gsub("^\r?\n", "")
    msg = msg:gsub(vim.pesc(temp), vim.fn.fnamemodify(path, ":~"))
    return msg
  end)
  pcall(vim.fn.delete, temp)
  if not ok then
    error(ret)
  end
  return ret
end

function M.write(expr, opts)
  local path = strip_prefix(expr)
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  opts = opts or {}
  local cmdarg = opts.cmdarg or vim.v.cmdarg
  local cmdbang = opts.cmdbang or vim.v.cmdbang
  local range = opts.range or ""

  local temp = vim.fn.tempname()
  local ok, ret = pcall(function()
    local write_cmd = string.format("%swrite%s %s %s", range, cmdbang and "!" or "", cmdarg, vim.fn.fnameescape(temp))
    local msg = vim.fn.execute(write_cmd):gsub("^\r?\n", "")

    local path_exists = (vim.fn.getftype(path) ~= "")

    if vim.fn.has("win32") == 1 then
      local tee = vim.fn.exepath("tee")
      local content = table.concat(vim.fn.readfile(temp, "b"), "\n")
      local result = M.system({ tee, path }, content)
      if vim.v.shell_error ~= 0 then
        error(result)
      end
    else
      local result = M.exec_with_suda({ "dd", "if=" .. temp, "of=" .. path, "bs=1048576" })
      if vim.v.shell_error ~= 0 then
        error(table.concat(result, "\n"))
      end
    end

    msg = msg:gsub(vim.pesc(temp), vim.fn.fnamemodify(path, ":~"))
    if path_exists then
      msg = msg:gsub("%[New%] ", "")
    end
    vim.fn.delete(temp)
    vim.cmd("checktime")
    return msg
  end)
  pcall(vim.fn.delete, temp)
  if not ok then
    error(ret)
  end
  return ret
end

----------------------------------------------------------------------
-- Autocommands
----------------------------------------------------------------------

local function buf_read_cmd()
  vim.cmd("doautocmd <nomodeline> BufReadPre")
  local ul = vim.o.undolevels
  vim.o.undolevels = -1
  vim.bo.swapfile = false
  vim.bo.undofile = false
  local ok, msg = pcall(function()
    local res = M.read("<afile>", { range = "1" })
    vim.cmd("silent lockmarks 0delete _")
    vim.bo.buftype = "acwrite"
    vim.bo.modified = false
    vim.cmd("filetype detect")
    return res
  end)
  vim.o.undolevels = ul
  if not ok then
    vim.api.nvim_echo({ { "[suda] " .. tostring(msg) } }, true, { err = true })
  else
    vim.api.nvim_echo({ { msg } }, true, {})
  end
  vim.cmd("doautocmd <nomodeline> BufReadPost")
end

local function file_read_cmd()
  vim.cmd("doautocmd <nomodeline> FileReadPre")
  local range = vim.fn.histget("cmd", -1):find("^0r%[ead]") and "0" or "'["
  local ok, msg = pcall(M.read, "<afile>", { range = range })
  if not ok then
    vim.api.nvim_echo({ { "[suda] " .. tostring(msg) } }, true, { err = true })
  else
    vim.api.nvim_echo({ { msg } }, true, {})
  end
  vim.cmd("doautocmd <nomodeline> FileReadPost")
end

local function buf_write_cmd_suda()
  vim.cmd("doautocmd <nomodeline> BufWritePre")
  local ok, msg = pcall(M.write, "<afile>", { range = "'[,'']" })
  if not ok then
    vim.api.nvim_echo({ { "[suda] " .. tostring(msg) } }, true, { err = true })
  else
    local lhs = vim.fn.expand("%:p")
    local rhs = vim.fn.expand("<afile>")
    if lhs == rhs or rhs:gsub("^suda://", "") == lhs then
      vim.bo.modified = false
    end
    vim.api.nvim_echo({ { msg } }, true, {})
  end
  vim.cmd("doautocmd <nomodeline> BufWritePost")
end

local function file_write_cmd_suda()
  vim.cmd("doautocmd <nomodeline> FileWritePre")
  local ok, msg = pcall(M.write, "<afile>", { range = "'[,'']" })
  if not ok then
    vim.api.nvim_echo({ { "[suda] " .. tostring(msg) } }, true, { err = true })
  else
    vim.api.nvim_echo({ { msg } }, true, {})
  end
  vim.cmd("doautocmd <nomodeline> FileWritePost")
end

local function smart_write(path)
  local buf = vim.api.nvim_get_current_buf()
  ---@diagnostic disable-next-line: param-type-mismatch
  local ok, _ = pcall(vim.cmd, "noautocmd write")
  if ok then
    vim.bo[buf].modified = false
    return
  end
  local w_ok, msg = pcall(M.write, path, {
    range = "'[,'']",
    cmdbang = vim.v.cmdbang,
    cmdarg = vim.v.cmdarg,
  })
  if w_ok then
    vim.bo[buf].modified = false
    vim.api.nvim_echo({ { msg } }, true, {})
  else
    vim.api.nvim_echo({ { "[suda] " .. tostring(msg) } }, true, { err = true })
  end
end

local function intercept_buf_write()
  vim.cmd("doautocmd <nomodeline> BufWritePre")
  local path = vim.fn.expand("<afile>")
  if path:match("^suda://") then
    buf_write_cmd_suda()
  else
    smart_write(path)
  end
  vim.cmd("doautocmd <nomodeline> BufWritePost")
end

local function intercept_file_write()
  vim.cmd("doautocmd <nomodeline> FileWritePre")
  local path = vim.fn.expand("<afile>")
  if path:match("^suda://") then
    file_write_cmd_suda()
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, _ = pcall(vim.cmd, "noautocmd write " .. vim.fn.fnameescape(path))
    if not ok then
      local w_ok, msg = pcall(M.write, path, {
        range = "'[,'']",
        cmdbang = vim.v.cmdbang,
        cmdarg = vim.v.cmdarg,
      })
      if not w_ok then
        vim.api.nvim_echo({ { "[suda] " .. tostring(msg) } }, true, { err = true })
      end
    end
  end
  vim.cmd("doautocmd <nomodeline> FileWritePost")
end

local function buf_enter()
  local buf = vim.fn.expand("<abuf>")
  local name = vim.fn.expand("<afile>")
  if vim.b[buf].suda_smart_edit_checked then
    return
  end
  vim.b[buf].suda_smart_edit_checked = true

  if name == "" or vim.bo.buftype ~= "" then
    return
  end
  if name:match("^%a+://") then
    return
  end
  if vim.fn.isdirectory(name) == 1 then
    return
  end
  if vim.fn.filereadable(name) == 1 and vim.fn.filewritable(name) == 1 then
    return
  end
  if vim.fn.empty(vim.fn.getftype(name)) == 1 then
    local parent = vim.fn.fnamemodify(name, ":p")
    while parent ~= vim.fn.fnamemodify(parent, ":h") do
      parent = vim.fn.fnamemodify(parent, ":h")
      if vim.fn.filewritable(parent) == 2 then
        return
      end
      if vim.fn.filereadable(parent) == 0 and vim.fn.isdirectory(parent) == 1 then
        break
      end
    end
  end
  vim.cmd("keepalt keepjumps edit suda://" .. vim.fn.fnameescape(vim.fn.fnamemodify(name, ":p")))
  vim.cmd("silent! " .. buf .. "bwipeout")
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

  -- Backward compatibility with vim.g variables
  if vim.g["suda_smart_edit"] ~= nil then
    M.config.smart_edit = vim.g["suda_smart_edit"]
  end
  if vim.g["suda#noninteractive"] ~= nil then
    M.config.noninteractive = vim.g["suda#noninteractive"]
  end
  if vim.g["suda#executable"] ~= nil then
    M.config.executable = vim.g["suda#executable"]
  end
  if vim.g["suda#prompt"] ~= nil then
    M.config.prompt = vim.g["suda#prompt"]
  end

  local suda_group = vim.api.nvim_create_augroup("suda_plugin", { clear = true })

  -- Register suda:// handlers
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = suda_group,
    pattern = "suda://*",
    callback = buf_read_cmd,
  })
  vim.api.nvim_create_autocmd("FileReadCmd", {
    group = suda_group,
    pattern = "suda://*",
    callback = file_read_cmd,
  })

  -- Write handling
  if M.config.intercept_write then
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      group = suda_group,
      pattern = "*",
      callback = intercept_buf_write,
    })
    vim.api.nvim_create_autocmd("FileWriteCmd", {
      group = suda_group,
      pattern = "*",
      callback = intercept_file_write,
    })
  else
    vim.api.nvim_create_autocmd("BufWriteCmd", {
      group = suda_group,
      pattern = "suda://*",
      callback = buf_write_cmd_suda,
    })
    vim.api.nvim_create_autocmd("FileWriteCmd", {
      group = suda_group,
      pattern = "suda://*",
      callback = file_write_cmd_suda,
    })
  end

  -- Smart edit
  if M.config.smart_edit then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = suda_group,
      pattern = "*",
      nested = true,
      callback = buf_enter,
    })
  end

  -- Commands
  vim.api.nvim_create_user_command("SudaRead", function(opts)
    local args = opts.args
    if args == "" then
      args = vim.fn.expand("%:p")
    end
    vim.cmd("edit suda://" .. vim.fn.fnameescape(args))
  end, { nargs = "?", complete = "file" })

  vim.api.nvim_create_user_command("SudaWrite", function(opts)
    local args = opts.args
    if args == "" then
      args = vim.fn.expand("%:p")
    end
    vim.cmd("write suda://" .. vim.fn.fnameescape(args))
  end, { nargs = "?", complete = "file" })
end

return M
