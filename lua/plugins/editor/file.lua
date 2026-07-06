---@type LazySpec
return {
  {
    -- [nsuda is a plugin to read or write files with sudo command]
    dir = vim.fn.stdpath("config"),
    name = "nsuda.nvim",
    opts = {
      smart_edit = true,
    },
  },
  {
    -- Neovim file explorer: edit your filesystem like a buffer
    -- https://github.com/stevearc/oil.nvim
    "stevearc/oil.nvim",
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    -- Optional dependencies
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
    keys = { { "<leader>f-", "<CMD>Oil<CR>", { desc = "Open parent directory" } } },
  },
}
