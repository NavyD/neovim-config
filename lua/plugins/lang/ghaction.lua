local help = require("utils.help")

local action_ft = "yaml.ghaction"
vim.filetype.add({
  pattern = {
    -- lua 模式不支持 (github|gitea/forgejo) 的方式
    [".*/%.github/workflows/.*%.ya?ml"] = action_ft,
    [".*/%.gitea/workflows/.*%.ya?ml"] = action_ft,
    [".*/%.forgejo/workflows/.*%.ya?ml"] = action_ft,
  },
})

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    opts = help.merge_lsp_opts_fn({
      servers = {
        gh_actions_ls = { filetypes = { action_ft } },
        yamlls = { filetypes = { action_ft } },
      },
    }),
  },
  {
    "mason-org/mason.nvim",
    ---@type LazyVimMasonOpts
    opts = { ensure_installed = { "actionlint" } },
  },
  {
    "mfussenegger/nvim-lint",
    ---@type LazyVimLintOpts
    opts = {
      linters_by_ft = { [action_ft] = { "actionlint" } },
    },
  },
}
