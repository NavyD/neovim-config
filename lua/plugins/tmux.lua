-- https://github.com/alexghergh/nvim-tmux-navigation#neovim
-- 配置中使用config=function()，但lazy.nvim插件建议使用[opts setup](https://lazy.folke.io/spec#spec-setup)，
-- 另外这个插件的setup key需要在keymaps.lua中配置
-- 参考https://github.com/LazyVim/LazyVim/discussions/4109#discussioncomment-10456484
--
-- 注意：需要单独配置tmux参考https://github.com/alexghergh/nvim-tmux-navigation#tmux
-- 可以使用[.tmux](https://github.com/gpakosz/.tmux)框架管理tmux
return {
  {
    "alexghergh/nvim-tmux-navigation",
    opts = {
      -- disable_when_zoomed = true,
    },
  },
}
