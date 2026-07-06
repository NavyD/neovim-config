---@type LazySpec
return {
  {
    -- [nsuda is a plugin to read or write files with sudo command](https://github.com/NavyD/nsuda.nvim)
    "navyd/nsuda.nvim",
    opts = {
      smart_edit = true,
    },
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
