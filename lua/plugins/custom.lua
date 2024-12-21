return {
  -- { "folke/noice.nvim", cond = not (vim.g.neovide or false) },
  -- 在windows禁用chezmoi 启动报错：
  -- ...lazy/LazyVim/lua/lazyvim/plugins/extras/util/chezmoi.lua:60: attempt to concatenate a nil value
  { "xvzc/chezmoi.nvim", cond = jit.os ~= "Windows" },
  { "alker0/chezmoi.vim", cond = jit.os ~= "Windows" },
  {
    "lewis6991/gitsigns.nvim",
    -- https://github.com/lewis6991/gitsigns.nvim#installation--usage
    opts = {
      -- Toggle with `:Gitsigns toggle_current_line_blame`
      -- 启用git blame line
      current_line_blame = true,
    },
  },
}
