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
            -- 默认实现见 snacks.nvim/lua/snacks/picker/format.lua:723，
            -- 只有时间行被改动："%R"→"%T"、宽度 5→8，其余完全照搬
            ---@see snacks.picker.formatters.notification
            format = function(item, picker)
              local a = Snacks.picker.util.align
              ---@type snacks.picker.Highlight[]
              local ret = {}
              ---@type snacks.notifier.Notif
              local notif = item.item
              -- added 为纳秒精度浮点秒，手动拆分秒与毫秒（%f 不被 LuaJIT 支持）
              local sec = math.floor(notif.added)
              local ms = math.floor((notif.added % 1) * 1000 + 0.5) -- 四舍五入避免浮点误差
              local time = os.date("%T", sec) .. string.format(".%03d", ms)
              ret[#ret + 1] = { a(time, #time), "SnacksPickerTime" }
              ret[#ret + 1] = { " " }
              if item.severity then
                vim.list_extend(
                  ret,
                  Snacks.picker.format.severity(item, picker)
                )
              end
              ret[#ret + 1] = { " " }
              ret[#ret + 1] =
                { a(notif.title or "", 15), "SnacksNotifierHistoryTitle" }
              ret[#ret + 1] = { " " }
              ret[#ret + 1] = { notif.msg, "SnacksPickerNotificationMessage" }
              Snacks.picker.highlight.markdown(ret)
              return ret
            end,
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
      {
        "<leader><space>",
        "<Plug>(NeuralOpen)",
        desc = "Neural Open Files with Snacks.picker",
      },
    },
    -- opts are optional. NeuralOpen will automatically use the defaults below.
    ---@module 'neural-open'
    ---@type NosConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {},
  },
}
