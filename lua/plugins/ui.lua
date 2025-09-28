-- editorconfig-checker-disable
---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    config = function()
      -- https://github.com/rachartier/tiny-inline-diagnostic.nvim/#configuration
      require("tiny-inline-diagnostic").setup({
        options = {
          -- Display the source of the diagnostic (e.g., basedpyright, vsserver, lua_ls etc.)
          show_source = {
            enabled = true,
            if_many = true,
          },
          -- Configuration for multiline diagnostics
          -- Can be a boolean or a table with detailed options
          multilines = {
            enabled = true,
          },
          -- Events to attach diagnostics to buffers
          -- Default: { "LspAttach" }
          -- Only change if the plugin doesn't work with your configuration
          -- [Diagnostics not shown from nvim-lint #40](https://github.com/rachartier/tiny-inline-diagnostic.nvim/issues/40#issuecomment-2331128814)
          -- overwrite_events = { "DiagnosticChanged", "BufEnter" },
        },
      })
      vim.diagnostic.config({ virtual_text = false }) -- Disable default virtual text
    end,
  },
  {
    -- [Modular nvim codelens support with inline references, git blame and more](https://github.com/oribarilan/lensline.nvim)
    "oribarilan/lensline.nvim",
    version = "*", -- or: branch = 'release/1.x' for latest non-breaking updates
    event = "LspAttach",
    opts = {
      style = {
        placement = "inline",
        prefix = "",
        render = "focused", -- or "all" for showing lenses in all functions
      },
    },
    -- config = function()
    --   require("lensline").setup()
    -- end,
  },
  {
    "nvim-mini/mini.animate",
    optional = true,
    -- NOTE: 在 vscode 中禁用避免滚动出问题，使用 `vscode=true` 无效
    cond = vim.g.neovide == nil and vim.g.vscode == nil,
  },
}
