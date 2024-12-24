-- fix: 在windows上无HOME变量导致nil连接str出错
-- lazy/LazyVim/lua/lazyvim/plugins/extras/util/chezmoi.lua:60: attempt to concatenate a nil value
-- lazy/LazyVim/lua/lazyvim/plugins/extras/util/chezmoi.lua:31: attempt to concatenate a nil value
if jit.os == "Windows" then
  -- NOTE: 不能是`C:\Users\xxxuser`，会导致lua连接成的path str 可能无法被找到
  -- 如果是`\`类型将会无法触发create_autocmd edit
  vim.env.HOME = os.getenv("USERPROFILE"):gsub("\\", "/")
end

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
}
