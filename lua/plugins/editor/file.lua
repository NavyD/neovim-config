---@type LazySpec
return {
  {
    -- [nsuda — sudo plugin for Neovim](https://github.com/lambdalisue/vim-suda)
    dir = vim.fn.stdpath("config") .. "/lua/utils/nsuda",
    opts = { smart_edit = true },
  },
  {
    -- Neovim file explorer: edit your filesystem like a buffer
    "stevearc/oil.nvim",
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },
    lazy = false,
    keys = { { "<leader>f-", "<CMD>Oil<CR>", { desc = "Open parent directory" } } },
  },
}
