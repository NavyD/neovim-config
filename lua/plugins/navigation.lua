-- [tmux integration for nvim features pane movement and resizing from within nvim.](https://github.com/aserowy/tmux.nvim)
-- 参考[Compatibility with vim-yoink or other yank-related plugins #88](https://github.com/aserowy/tmux.nvim/issues/88#issuecomment-2259591730)
-- 参考https://github.com/moetayuko/nvimrc/blob/master/lua/plugins/tmux.lua
-- 目前仅替换了按键从`A[lt]`->`C[trl]`
---@type LazyPluginSpec[]
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
      ---@diagnostic disable-next-line: redundant-parameter
      require("tmux").setup(opts)
      if vim.env.TMUX then
        LazyVim.on_load("which-key.nvim", function()
          local reg = require("which-key.plugins.registers")
          local expand = reg.expand
          ---@diagnostic disable-next-line: duplicate-set-field
          function reg.expand()
            require("tmux.copy").sync_registers()
            return expand()
          end
        end)

        if LazyVim.has("yanky.nvim") then
          LazyVim.on_load("yanky.nvim", function()
            local yanky = require("yanky")
            local put = yanky.put
            ---@diagnostic disable-next-line: duplicate-set-field
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
  {
    -- A neovim plugin for moving around your code in a syntax tree aware manner
    -- https://github.com/aaronik/treewalker.nvim
    "aaronik/treewalker.nvim",
    -- enable in vscode or anywhere
    cond = true,
    opts = {},
    keys = {
      {
        "[o",
        "<cmd>Treewalker Up<cr>",
        desc = "Moves up to the previous neighbor node",
        mode = { "n", "v" },
      },
      {
        "]o",
        -- "<M-Down>",
        "<cmd>Treewalker Down<cr>",
        desc = "Moves up to the next neighbor node",
        mode = { "n", "v" },
      },
      {
        "[O",
        "<cmd>Treewalker Left<cr>",
        desc = "Moves to the first ancestor node that's on a different line from the current node",
        mode = { "n", "v" },
      },
      {
        "]O",
        "<cmd>Treewalker Right<cr>",
        desc = "Moves to the next node down that's indented further than the current node",
        mode = { "n", "v" },
      },
      {
        "<M-up>", -- OR: "<M-S-up>",
        "<cmd>Treewalker SwapUp<cr>",
        desc = "Swaps up to the previous neighbor node",
        mode = { "n", "v" },
      },
      {
        "<M-Down>",
        "<cmd>Treewalker SwapDown<cr>",
        desc = "Swaps up to the next neighbor node",
        mode = { "n", "v" },
      },
      {
        "<M-Left>",
        "<cmd>Treewalker SwapLeft<cr>",
        desc = "Swaps to the first ancestor node that's on a different line from the current node",
        mode = { "n", "v" },
      },
      {
        "<M-Right>",
        "<cmd>Treewalker SwapRight<cr>",
        desc = "Swaps to the next node down that's indented further than the current node",
        mode = { "n", "v" },
      },
    },
  },
}
