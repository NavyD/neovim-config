-- lua/navyd/nsuda.lua
local M = {}

---@class nsuda.WriteCtx
---@field error  string
---@field path   string
---@field buf    integer

---@class nsuda.ElevationBuilder
---@field build      fun(cmd: string[]): string[]
---@field build_auth fun(cmd: string[]): string[]?

---@class nsuda.SystemResult
---@field code    integer
---@field stdout  string
---@field stderr  string

---@class nsuda.Config
---@field executable?            string
---@field noninteractive?        boolean
---@field prompt?                string
---@field smart_edit?            boolean
---@field write_error_handler?   fun(ctx: nsuda.WriteCtx): boolean
---@field builders?              table<string, nsuda.ElevationBuilder>

if not vim.uv then
  error("[nsuda] Requires Neovim 0.10+")
end

local is_windows = vim.uv.os_uname().sysname == "Windows_NT"
---@type nsuda.Config
local config = {
  noninteractive = false,
  prompt = "Password: ",
  smart_edit = false,
}

---@type integer  augroup ID, set in setup()
local suda_group = -1

--- raw copy command (no elevation prefix)
---@param src string
---@param dst string
---@return string[]
local function raw_copy_cmd(src, dst)
  if is_windows then
    return { "cmd", "/c", "copy", "/y", src, dst }
  end
  return { "dd", "if=" .. src, "of=" .. dst, "bs=1M" }
end

local default_builders = {
  sudo = {
    build = function(cmd)
      return vim.list_extend({ "sudo", "-n" }, cmd)
    end,
    build_auth = function(cmd)
      return vim.list_extend({ "sudo", "-S", "-p", "" }, cmd)
    end,
  },
  gsudo = {
    build = function(cmd)
      return vim.list_extend({ "gsudo" }, cmd)
    end,
    build_auth = nil,
  },
}

--- resolve the ElevationBuilder for the current executable
---@return nsuda.ElevationBuilder
local function resolve_builder()
  local name = config.executable
  local builders = config.builders or default_builders
  return builders[name] or error("[nsuda] No builder for executable: " .. (name or "nil"))
end

---@param cmd string[]
---@param opts? { stdin?: string }
---@return nsuda.SystemResult
function M.system(cmd, opts)
  opts = opts or {}
  local b = resolve_builder()

  -- 1. Try without password (cached / UAC)
  local args = b.build(cmd)
  local r = vim.system(args, { text = true, stdin = opts.stdin }):wait()
  if r.code == 0 then
    return r
  end

  -- 2. Auth mode (only if builder supports it and not noninteractive)
  if b.build_auth and not config.noninteractive then
    local pwd
    vim.fn.inputsave()
    vim.cmd.redraw()
    pwd = vim.fn.inputsecret(config.prompt)
    vim.fn.inputrestore()

    local auth_args = b.build_auth(cmd)
    local stdin = pwd .. "\n" .. (opts.stdin or "")
    return vim.system(auth_args, { text = true, stdin = stdin }):wait()
  end

  return r
end

---@param src string
---@param dst string
---@return nsuda.SystemResult
function M.copy(src, dst)
  return M.system(raw_copy_cmd(src, dst))
end

---@param path string
---@return string[]
function M.read(path)
  path = (path:gsub("^(suda://)+", ""))
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")

  local stat = vim.uv.fs_stat(path)
  if stat and stat.type == "file" and vim.uv.fs_access(path, "R") then
    return vim.fn.readfile(path, "b")
  end

  local tmp = vim.fn.tempname()
  local r = M.copy(path, tmp)
  if r.code ~= 0 then
    pcall(vim.uv.fs_unlink, tmp)
    error("[nsuda] Cannot read " .. path .. ": " .. r.stderr)
  end
  local lines = vim.fn.readfile(tmp, "b")
  vim.uv.fs_unlink(tmp)
  return lines
end

---@param path string
---@param lines? string[]
function M.write(path, lines)
  path = (path:gsub("^(suda://)+", ""))
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  lines = lines or vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local tmp = vim.fn.tempname()
  vim.fn.writefile(lines, tmp, "b")
  local r = M.copy(tmp, path)
  vim.uv.fs_unlink(tmp)
  if r.code ~= 0 then
    error("[nsuda] Cannot write " .. path .. ": " .. r.stderr)
  end
end

local remembered_dirs = {}

---@param ctx nsuda.WriteCtx
local function default_write_error_handler(ctx)
  return ctx.error:match("E212:")
    and ctx.error:lower():match("permission denied|operation not permitted")
end

---@param path string   target file path
---@return boolean   true = proceed with elevation
local function confirm_elevation(path)
  if config.noninteractive then
    return true
  end
  local dir = vim.fs.dirname(path)
  if remembered_dirs[dir] then
    return true
  end
  local choice = vim.fn.confirm(
    "[nsuda] Elevate and save " .. vim.fn.fnamemodify(path, ":~") .. "?",
    "&Yes\n&Remember\n&No", 1, "Question"
  )
  if choice == 0 or choice == 3 then
    return false
  end
  if choice == 2 then
     remembered_dirs[dir] = true
  end
  return true
end

---@param buf integer
---@param path string   real filesystem path (suda:// already stripped)
local function handle_suda_read(buf, path)
  vim.cmd("doautocmd <nomodeline> BufReadPre")

  local ul = vim.o.undolevels
  vim.o.undolevels = -1
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false

  local ok, lines = pcall(M.read, path)
  if ok then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].modified = false
    vim.cmd("filetype detect")
  else
    vim.api.nvim_echo({ { "[nsuda] " .. tostring(lines) } }, true, { err = true })
  end

  vim.o.undolevels = ul
  vim.cmd("doautocmd <nomodeline> BufReadPost")
end

--- Write tempfile to target via elevation. Returns true on success.
---@param buf  integer
---@param path string   real filesystem path
---@param tmp  string   tempfile path with buffer content already written
---@return boolean
local function do_elevated_write(buf, path, tmp)
  local r = M.copy(tmp, path)
  if r.code == 0 then
    vim.bo[buf].modified = false
    vim.notify("[nsuda] Saved " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
    return true
  end
  vim.api.nvim_echo({ { "[nsuda] " .. r.stderr } }, true, { err = true })
  return false
end

---@param buf  integer
---@param path string   real filesystem path (suda:// already stripped)
local function handle_suda_protocol_write(buf, path)
  vim.cmd("doautocmd <nomodeline> BufWritePre")

  local tmp = vim.fn.tempname()
  vim.cmd("noautocmd write! " .. vim.fn.fnameescape(tmp))
  do_elevated_write(buf, path, tmp)
  vim.uv.fs_unlink(tmp)

  vim.cmd("doautocmd <nomodeline> BufWritePost")
end

---@param buf  integer
---@param path string   real filesystem path (no suda:// prefix)
local function handle_smart_write(buf, path)
  vim.cmd("doautocmd <nomodeline> BufWritePre")

  local buftype_saved = vim.bo[buf].buftype
  vim.bo[buf].buftype = ""

  local ok, err = pcall(vim.cmd, "noautocmd write")
  vim.bo[buf].buftype = buftype_saved

  if ok then
    vim.bo[buf].modified = false
    vim.cmd("doautocmd <nomodeline> BufWritePost")
    return
  end

  local handler = config.write_error_handler or default_write_error_handler
  local ctx = { error = tostring(err), path = path, buf = buf }
  if not handler(ctx) then
    vim.api.nvim_echo({ { "[nsuda] " .. tostring(err) } }, true, { err = true })
    vim.cmd("doautocmd <nomodeline> BufWritePost")
    return
  end

  local tmp = vim.fn.tempname()
  vim.cmd("noautocmd write! " .. vim.fn.fnameescape(tmp))

  if not confirm_elevation(path) then
    vim.uv.fs_unlink(tmp)
    vim.notify("[nsuda] Elevation cancelled", vim.log.levels.WARN)
    vim.cmd("doautocmd <nomodeline> BufWritePost")
    return
  end

  do_elevated_write(buf, path, tmp)
  vim.uv.fs_unlink(tmp)

  vim.cmd("doautocmd <nomodeline> BufWritePost")
end

return M
