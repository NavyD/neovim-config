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

return M
