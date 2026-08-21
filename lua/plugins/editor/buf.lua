---@type LazySpec
return {
  {
    -- [sleuth.vim: Heuristically set buffer options](https://github.com/tpope/vim-sleuth)
    "tpope/vim-sleuth",
  },
  {
    -- Send buffers into early retirement by automatically closing them
    -- after x minutes of inactivity.
    -- https://github.com/chrisgrieser/nvim-early-retirement
    "chrisgrieser/nvim-early-retirement",
    event = "VeryLazy",
    ---@module 'early-retirement'
    ---@type opts
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      retirementAgeMins = 15,
      notificationOnAutoClose = true,
      minimumBufferNum = 10,
    },
  },
}
