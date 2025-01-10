return {
  -- { "folke/noice.nvim", cond = not (vim.g.neovide or false) },
  {
    "lewis6991/gitsigns.nvim",
    -- https://github.com/lewis6991/gitsigns.nvim#installation--usage
    opts = {
      -- Toggle with `:Gitsigns toggle_current_line_blame`
      -- 启用git blame line
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
      },
    },
  },
  -- 禁用init 避免在打开cz文件时卡顿
  { "xvzc/chezmoi.nvim", enabled = true, init = function() end },
  {
    "gbprod/yanky.nvim",
    -- 在termux中无效且可能会在打开文件时阻塞 禁止加载
    cond = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
  },
}
