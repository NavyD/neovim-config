---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    -- A smart picker for Snacks.nvim that trains a neural network with your file picking preferences.
    -- https://github.com/dtormoen/neural-open.nvim
    "dtormoen/neural-open.nvim",
    dependencies = {
      {
        "folke/snacks.nvim",
        ---@module 'snacks'
        ---@type snacks.Config
        opts = {},
      },
    },
    -- NeuralOpen implements lazy loading internally. It needs to be loaded for recency tracking to work.
    lazy = false,
    keys = {
      { "<leader><space>", "<Plug>(NeuralOpen)", desc = "Neural Open Files with Snacks.picker" },
    },
    -- opts are optional. NeuralOpen will automatically use the defaults below.
    ---@module 'neural-open'
    ---@type NosConfig
    opts = {},
  },
}
