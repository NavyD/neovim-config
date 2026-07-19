---@type LazySpec
return {
  {
    dir = vim.fs.joinpath(vim.fn.stdpath("config"), "local_plugins/nsuda"),
    ---@type nsuda.Config
    ---@diagnostic disable-next-line: missing-fields
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
