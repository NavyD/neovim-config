-- editorconfig-checker-disable
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
}
