if true then
  return {}
end

-- 问题：
-- 1. 左边缘有间隔影响观感，但看其它人的截图是正常的，应该是不兼容
-- 2. 不能设置在窗口宽度小时自动关闭map避免遮挡内容
return {
  ---@module "neominimap.config.meta"
  {
    "Isrothy/neominimap.nvim",
    version = "v3.*.*",
    enabled = true,
    lazy = false, -- NOTE: NO NEED to Lazy load
    -- Optional
    keys = {
      -- Global Minimap Controls
      { "<leader>mm", "<cmd>Neominimap toggle<cr>", desc = "Toggle global minimap" },
      -- { "<leader>mo", "<cmd>Neominimap on<cr>", desc = "Enable global minimap" },
      -- { "<leader>mc", "<cmd>Neominimap off<cr>", desc = "Disable global minimap" },
      { "<leader>mr", "<cmd>Neominimap refresh<cr>", desc = "Refresh global minimap" },

      -- Window-Specific Minimap Controls
      { "<leader>mwt", "<cmd>Neominimap winToggle<cr>", desc = "Toggle minimap for current window" },
      { "<leader>mwr", "<cmd>Neominimap winRefresh<cr>", desc = "Refresh minimap for current window" },
      { "<leader>mwo", "<cmd>Neominimap winOn<cr>", desc = "Enable minimap for current window" },
      { "<leader>mwc", "<cmd>Neominimap winOff<cr>", desc = "Disable minimap for current window" },

      -- Tab-Specific Minimap Controls
      { "<leader>mtt", "<cmd>Neominimap tabToggle<cr>", desc = "Toggle minimap for current tab" },
      { "<leader>mtr", "<cmd>Neominimap tabRefresh<cr>", desc = "Refresh minimap for current tab" },
      { "<leader>mto", "<cmd>Neominimap tabOn<cr>", desc = "Enable minimap for current tab" },
      { "<leader>mtc", "<cmd>Neominimap tabOff<cr>", desc = "Disable minimap for current tab" },

      -- Buffer-Specific Minimap Controls
      { "<leader>mbt", "<cmd>Neominimap bufToggle<cr>", desc = "Toggle minimap for current buffer" },
      { "<leader>mbr", "<cmd>Neominimap bufRefresh<cr>", desc = "Refresh minimap for current buffer" },
      { "<leader>mbo", "<cmd>Neominimap bufOn<cr>", desc = "Enable minimap for current buffer" },
      { "<leader>mbc", "<cmd>Neominimap bufOff<cr>", desc = "Disable minimap for current buffer" },

      ---Focus Controls
      { "<leader>mf", "<cmd>Neominimap focus<cr>", desc = "Focus on minimap" },
      { "<leader>mu", "<cmd>Neominimap unfocus<cr>", desc = "Unfocus minimap" },
      { "<leader>ms", "<cmd>Neominimap toggleFocus<cr>", desc = "Switch focus on minimap" },
    },
    init = function()
      -- The following options are recommended when layout == "float"
      -- 当文本超出一行显示时，是否换行显示
      vim.opt.wrap = true
      -- 光标上方和下方保留的最小屏幕行数，移动时有用
      -- vim.opt.sidescrolloff = 36 -- Set a large value

      --- Put your configuration here
      vim.g.neominimap = {
        -- 默认禁用
        auto_enable = false,
        -- layout = "split",
        -- 在map中一个方块显示几列，用于缩大小
        x_multiplier = 4,
        click = { enabled = true },
        winopt = function(opt, winid)
          -- local snacks = require("snacks")
          -- snacks.notify.info("winopt")
          -- if vim.api.nvim_win_get_width(winid) < 90 then
          --   local map_winid = vim.api.nvim_get_current_win()
          --   vim.api.nvim_win_close(map_winid, false)
          -- end
          -- opt.number = true
          -- opt.wrap = true
        end,
      }
    end,
  },
}
