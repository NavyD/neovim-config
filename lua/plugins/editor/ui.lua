---@module 'lazy'
---@type LazySpec
return {
  {
    "nvim-mini/mini.animate",
    optional = true,
    -- NOTE: 在 vscode 中禁用避免滚动出问题，使用 `vscode=true` 无效
    cond = vim.g.neovide == nil and vim.g.vscode == nil,
  },
  {
    "m4xshen/smartcolumn.nvim",
    -- https://github.com/m4xshen/smartcolumn.nvim#-configuration
    opts = {
      -- 默认不显示，仅当存在 editorconfig 时自动启用
      colorcolumn = "0",
      disabled_filetypes = {
        "alpha",
        "calendar",
        "help",
        "text",
        -- "markdown",
        "NvimTree",
        "lazy",
        "mason",
        "help",
        "checkhealth",
        "lspinfo",
        -- typos: disable-next-line
        "noice",
        "Trouble",
        "fish",
        "zsh",
      },
      scope = "file",
      editorconfig = true,
    },
  },
  {
    ---[A Neovim plugin that displays interactive vertical scrollbars and signs.](https://github.com/dstein64/nvim-scrollview)
    "dstein64/nvim-scrollview",
    -- 参考github相关仓库，或使用`VeryLazy`事件，否则无效
    event = { "BufReadPost", "BufAdd", "BufNewFile" },
    keys = {
      { "<leader>uR", "<cmd>ScrollViewToggle<cr>", desc = "Toggle Scroll View" },
    },
    opts = {},
  },
}
