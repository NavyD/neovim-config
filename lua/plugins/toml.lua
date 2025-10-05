---@module 'lazyvim'
---@type LazyPluginSpec
return {
  "neovim/nvim-lspconfig",
  ---@module 'lspconfig.configs'
  ---@type PluginLspOpts
  opts = {
    ---@type table<string, lazyvim.lsp.Config|boolean>
    servers = {
      -- 禁用 lazyvim 自带的 taplo 服务（不再活跃开发），使用 tombi 代替
      -- [TOML Formatter / Linter / Language Server](https://github.com/tombi-toml/tombi)
      -- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/lang/toml.lua
      taplo = { enabled = false },
      tombi = {},
    },
  },
}
