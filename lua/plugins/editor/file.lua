---@type LazySpec
return {
  {
    -- [suda is a plugin to read or write files with sudo command](https://github.com/lambdalisue/vim-suda)
    "lambdalisue/suda.vim",
    init = function()
      -- 自动读写需要的使用sudo的文件 https://github.com/lambdalisue/vim-suda#smart-edit
      vim.g.suda_smart_edit = 1
    end,
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
