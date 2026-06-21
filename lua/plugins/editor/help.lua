---@module 'lazy'
---@type LazySpec
return {
  {
    -- [A hackable & fancy vimdoc/help file viewer for Neovim](https://github.com/OXY2DEV/helpview.nvim)
    "OXY2DEV/helpview.nvim",
    lazy = false,
  },
  {
    -- https://github.com/saxon1964/neovim-tips#-features
    "saxon1964/neovim-tips",
    version = "*", -- Only update on tagged releases
    dependencies = {
      "MunifTanjim/nui.nvim",
      -- OPTIONAL: Choose your preferred markdown renderer (or omit for raw markdown)
      -- "MeanderingProgrammer/render-markdown.nvim", -- Clean rendering
      "OXY2DEV/markview.nvim", -- Rich rendering with advanced features
    },
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
    lazy = true,
    init = function()
      -- 仅在 session 加载后运行
      -- https://github.com/saxon1964/neovim-tips/blob/1339a0da1ff59fab8cfc07661ef92aa8c7d07f79/lua/neovim_tips/init.lua#L208
      vim.api.nvim_create_autocmd("SessionLoadPost", {
        pattern = "*",
        -- group = vim.api.nvim_create_augroup("NeovimaapiSessionLoadGroup", { clear = true }),
        once = true,
        callback = function()
          local req_ok, utils = pcall(require, "neovim_tips.utils")
          if not req_ok then
            return
          end
          utils.run_async(require("neovim_tips.loader").load, function(ok, _)
            if ok then
              require("neovim_tips.daily_tip").check_and_show()
            end
          end)
        end,
      })
    end,
  },
}
