-- [tmux integration for nvim features pane movement and resizing from within nvim.](https://github.com/aserowy/tmux.nvim)
-- 参考[Compatibility with vim-yoink or other yank-related plugins #88](https://github.com/aserowy/tmux.nvim/issues/88#issuecomment-2259591730)
-- 参考https://github.com/moetayuko/nvimrc/blob/master/lua/plugins/tmux.lua
-- 目前仅替换了按键从`A[lt]`->`C[trl]`
return {
  {
    "aserowy/tmux.nvim",
    event = "VeryLazy",
    opts = {
      navigation = {
        enable_default_keybindings = false,
      },
      resize = {
        enable_default_keybindings = false,
      },
      copy_sync = {
        enable = true,
        sync_registers_keymap_put = false,
        sync_registers_keymap_reg = false,
      },
    },
    config = function(_, opts)
      require("tmux").setup(opts)
      if vim.env.TMUX then
        LazyVim.on_load("which-key.nvim", function()
          local reg = require("which-key.plugins.registers")
          local expand = reg.expand
          function reg.expand()
            require("tmux.copy").sync_registers()
            return expand()
          end
        end)

        if LazyVim.has("yanky.nvim") then
          LazyVim.on_load("yanky.nvim", function()
            local yanky = require("yanky")
            local put = yanky.put
            function yanky.put(type, is_visual, callback)
              require("tmux.copy").sync_registers()
              return put(type, is_visual, callback)
            end
          end)
        end
      end
    end,
    keys = {
      {
        "<C-H>",
        function()
          require("tmux").move_left()
        end,
        desc = "Go to left window",
        remap = true,
      },
      {
        "<C-J>",
        function()
          require("tmux").move_bottom()
        end,
        desc = "Go to lower window",
        remap = true,
      },
      {
        "<C-K>",
        function()
          require("tmux").move_top()
        end,
        desc = "Go to upper window",
        remap = true,
      },
      {
        "<C-L>",
        function()
          require("tmux").move_right()
        end,
        desc = "Go to right window",
        remap = true,
      },
    },
  },
}
