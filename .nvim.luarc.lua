-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/configs/lua_ls.lua
-- [lua ls: Settings](https://luals.github.io/wiki/settings/)
---@type _.lspconfig.settings.lua_ls.Config
---@diagnostic disable: missing-fields
local lua_ls_settings = {
  ---@type _.lspconfig.settings.lua_ls.Runtime
  runtime = { version = "LuaJIT" },
  ---@type _.lspconfig.settings.lua_ls.Format
  format = { enable = true },
  ---@type _.lspconfig.settings.lua_ls.Workspace
  workspace = {
    checkThirdParty = false,
    library = {
      vim.env.VIMRUNTIME,
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.fs.joinpath(vim.fn.stdpath("data"), "lazy"),
      -- Depending on the usage, you might want to add additional paths here.
      "${3rd}/luv/library",
      "${3rd}/busted/library",
    },
    -- An array of paths that will be ignored and not included in the workspace diagnosis. Uses .gitignore grammar. Can be a file or directory.
    -- https://luals.github.io/wiki/settings/#workspaceignoredir
    -- ignoreDir = {"/lua/plugins/example.lua"}
  },
}
local settings_json = vim.fn.json_encode(lua_ls_settings)

-- vim.print(vim.inspect(arg) .. " len: " .. #arg .. " arg1=" .. arg[1])
if #arg <= 0 then
  vim.print(settings_json)
  return
end
if #arg > 1 then
  error("invalid args: " .. vim.inspect(arg))
  return
end

-- 输出 json 到文件
local file, open_err = io.open(arg[1], "w+")
if not file then
  error(open_err)
  return
end
file:write(settings_json)
  file:close()


