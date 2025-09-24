---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "mason-org/mason.nvim",
    ---@module 'mason'
    ---@type MasonSettings
    opts = {
      ensure_installed = {
        "editorconfig-checker",
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        ["*"] = { "editorconfig-checker" },
      },
    },
  },
}
