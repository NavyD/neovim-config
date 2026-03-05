---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#files
          files = {
            -- 默认显示隐藏文件
            hidden = true,
            ignored = false,
          },
          explorer = {
            -- 默认显示隐藏文件
            hidden = true,
            ignored = false,
          },
          notifications = {
            win = {
              preview = {
                wo = {
                  -- 查看通知的preview避免隐藏超出列长的部分
                  -- notifications 预览应该 wrap 避免无法查看全部或 item 被wrap
                  -- NOTE: 聚焦到 preview 上使用 `<a-w>`
                  -- editorconfig-checker-disable
                  -- 参考 [How to scroll preview panel in git log? #5523](https://github.com/LazyVim/LazyVim/discussions/5523#discussioncomment-12060745)
                  -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#snackspickeractionscycle_win
                  -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-config
                  -- editorconfig-checker-enable
                  wrap = true,
                },
              },
            },
          },
        },
      },
    },
    keys = {
      -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#zoxide
      {
        "<leader>fz",
        function()
          Snacks.picker.zoxide()
        end,
        mode = { "n", "x" },
        desc = "Zoxide",
      },
    },
  },
  {
    -- A smart picker for Snacks.nvim that trains a neural network with your file picking preferences.
    -- https://github.com/dtormoen/neural-open.nvim
    "dtormoen/neural-open.nvim",
    version = "*",
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
    ---@diagnostic disable-next-line: missing-fields
    opts = {},
  },
}
