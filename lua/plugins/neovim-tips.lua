---@module 'lazyvim'
---@type LazyPluginSpec
-- https://github.com/saxon1964/neovim-tips#-features
return {
  "saxon1964/neovim-tips",
  version = "*", -- Only update on tagged releases
  dependencies = {
    "MunifTanjim/nui.nvim",
    -- OPTIONAL: Choose your preferred markdown renderer (or omit for raw markdown)
    -- "MeanderingProgrammer/render-markdown.nvim", -- Clean rendering
    "OXY2DEV/markview.nvim", -- Rich rendering with advanced features
  },
  lazy = false,
  keys = {
    { "<leader>cto", "<cmd>NeovimTips<cr>", desc = "Neovim tips", noremap = true, silent = true },
    { "<leader>cte", "<cmd>NeovimTipsEdit<cr>", desc = "Edit your Neovim tips", noremap = true, silent = true },
    { "<leader>cta", "<cmd>NeovimTipsAdd<cr>", desc = "Add your Neovim tip", noremap = true, silent = true },
    { "<leader>cth", "<cmd>help neovim-tips<cr>", desc = "Neovim tips help", noremap = true, silent = true },
    { "<leader>ctr", "<cmd>NeovimTipsRandom<cr>", desc = "Show random tip", noremap = true, silent = true },
    { "<leader>ctp", "<cmd>NeovimTipsPdf<cr>", desc = "Open Neovim tips PDF", noremap = true, silent = true },
  },
  ---@module 'neovim_tips'
  ---@type NeovimTipsOptions
  opts = {
    -- OPTIONAL: Location of user defined tips (default value shown below)
    user_file = vim.fn.stdpath("config") .. "/neovim_tips/user_tips.md",
    -- OPTIONAL: Prefix for user tips to avoid conflicts (default: "[User] ")
    user_tip_prefix = "[User] ",
    -- OPTIONAL: Show warnings when user tips conflict with builtin (default: true)
    warn_on_conflicts = true,
    -- OPTIONAL: Daily tip mode (default: 1)
    -- 0 = off, 1 = once per day, 2 = every startup
    daily_tip = 1,
    -- OPTIONAL: Bookmark symbol (default: "🌟 ")
    bookmark_symbol = "🌟 ",
  },
}
