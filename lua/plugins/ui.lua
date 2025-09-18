-- editorconfig-checker-disable
---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    -- NOTE: 临时禁用避免同时显示多种 diag 消息
    cond = false,
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
      -- FIXME:启动后会同时显示 2 种 diagnostic messages ，需要在 cmdline 中手动运行才可移除 virtual_text 的显示
      vim.diagnostic.config({ virtual_text = false }) -- Disable default virtual text
    end,
  },
}
