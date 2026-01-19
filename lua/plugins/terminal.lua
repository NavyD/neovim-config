---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    -- [No worry about nested Nvim in Nvim terminal](https://github.com/brianhuster/unnest.nvim)
    "brianhuster/unnest.nvim",
    lazy = false,
  },
  {
    "folke/snacks.nvim",
    ---@module 'snacks'
    ---@type snacks.Config
    opts = {
      styles = {
        -- NOTE: terminal 的配置会影响 lazygit，必须覆盖
        lazygit = { height = 0.9, on_close = function() end },
        terminal = {
          height = function(_)
            -- 使用大写开头可让 sessionoptions globals 持久化变量值
            return vim.g.Snacks_terminal_height or 0.48
          end,
          on_close = function(w)
            -- 使用百分比的方法可以在窗口关闭打开时与 resized 事件放大/缩小窗口，
            -- 也可以仅使用 height >= 1 的固定大小
            vim.g.Snacks_terminal_height = vim.api.nvim_win_get_height(w.win) / vim.o.lines
          end,
        },
      },
    },
  },
  -- {
  --   -- https://github.com/akinsho/toggleterm.nvim
  --   "akinsho/toggleterm.nvim",
  --   version = "*",
  --   lazy = true,
  --   ---@module 'toggleterm'
  --   ---@type ToggleTermConfig
  --   ---@diagnostic disable: missing-fields
  --   opts = {
  --     persist_size = true,
  --   },
  --   ---@diagnostic enable: missing-fields
  --   cmd = { "ToggleTerm", "ToggleTermOpenAll", "ToggleTermCloseAll" },
  --   keys = {
  --     { "<C-/>", "<cmd>ToggleTerm<cr>", desc = "Open ToggleTerm" },
  --   },
  -- },
}
