---@type LazySpec
return {
  {
    -- A Neovim plugin for changing keyword case.
    -- https://github.com/gregorias/coerce.nvim
    "gregorias/coerce.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
      { "gregorias/coop.nvim", lazy = true },
      { "folke/which-key.nvim" },
    },
    ---@module 'coerce'
    ---@param opts CoerceConfigUser
    config = function(_, opts)
      require("coerce").setup(opts)
      local wke = require("coerce.keymaps").which_key_expand
      require("which-key").add({
        -- {
        --   "m",
        --   group = "+Coerce word",
        --   expand = wke.normal_mode,
        --   -- 在 `d,y,c,g` 等等待下一个操作
        --   mode = "o",
        -- },
        {
          -- NOTE: 需要快速按下
          "cm",
          group = "+Coerce word",
          expand = wke.normal_mode,
          mode = "n",
        },
        -- 不能用 gc 会占用默认的 gc 注释功能
        {
          "gzcm",
          group = "+Coerce motion",
          expand = wke.motion_mode,
          mode = "n",
        },
        {
          "gzcm",
          group = "+Coerce visual",
          expand = wke.visual_mode,
          mode = "x",
        },
      })
    end,
  },
}
