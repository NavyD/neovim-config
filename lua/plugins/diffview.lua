-- 参考https://github.com/sindrets/diffview.nvim
---@class LazyPluginSpec
return {
  "sindrets/diffview.nvim",
  enabled = true,
  keys = {
    {
      "<leader>gd",
      -- 使用一个函数打开关闭diffview窗口
      -- 参考[[Feature Request] DiffviewToggle command. #450](https://github.com/sindrets/diffview.nvim/issues/450)
      function()
        local lib = require("diffview.lib")
        local view = lib.get_current_view()
        if view then
          -- Current tabpage is a Diffview; close it
          vim.cmd.DiffviewClose()
        else
          -- No open Diffview exists: open a new one
          vim.cmd.DiffviewOpen()
        end
      end,
      desc = "Toggle diffview",
    },
  },
  opts = {},
}
