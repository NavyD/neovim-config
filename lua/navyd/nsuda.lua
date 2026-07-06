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

return M
