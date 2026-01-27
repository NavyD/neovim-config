---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = {
      {
        -- Ripgrep/gitgrep source for the blink.cmp Neovim completion plugin
        -- https://github.com/mikavilpas/blink-ripgrep.nvim
        "mikavilpas/blink-ripgrep.nvim",
        version = "*",
      },
    },
    ---@type BlinkCmpConfigExt
    opts = {
      completion_source_icons = { ripgrep = "󱪣" },
      sources = {
        default = { "ripgrep" },
        providers = {
          ripgrep = {
            module = "blink-ripgrep",
            enabled = vim.fn.executable("rg") == 1 or vim.fn.executable("git") == 1,
            -- async = true,
            score_offset = -5,
            name = "ripgrep",
            -- see the full configuration below for all available options
            -- https://github.com/mikavilpas/blink-ripgrep.nvim#full-config
            ---@module "blink-ripgrep"
            ---@type blink-ripgrep.Options
            opts = {
              prefix_min_len = 3,
              backend = {
                use = "gitgrep-or-ripgrep",
              },
            },
          },
        },
      },
    },
  },
}
