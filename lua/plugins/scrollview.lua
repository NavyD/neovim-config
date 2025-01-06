---[A Neovim plugin that displays interactive vertical scrollbars and signs.](https://github.com/dstein64/nvim-scrollview)
---@type LazySpec
return {
  {
    "dstein64/nvim-scrollview",
    -- 参考github相关仓库，或使用`VeryLazy`事件，否则无效
    event = { "BufReadPost", "BufAdd", "BufNewFile" },
    keys = {
      { "<leader>uR", "<cmd>ScrollViewToggle<cr>", desc = "Toggle Scroll View" },
    },
    opts = {},
  },
}
