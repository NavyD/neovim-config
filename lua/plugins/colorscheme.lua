---@type LazyPluginSpec[]
return {
  {
    -- [Remove all background colors to make nvim transparent](https://github.com/xiyaowong/transparent.nvim)
    "xiyaowong/transparent.nvim",
    lazy = false,
    -- https://github.com/lukejoshua/kickstart.nvim/blob/517f04d07eb8403e6f5ad72767a54ed9ac14bb92/lua/plugins/transparent.lua#L6
    config = function()
      -- [How can I make plugin lspsaga preview windows and neotree pop windows transparent? #25](https://github.com/xiyaowong/transparent.nvim/issues/25#issuecomment-1473711316)
      local extra_groups = {
        "NormalFloat",
        "FloatShadow",
        "FloatBorder",
        "TelescopePromptTitle",
        "TelescopePromptBorder",
        "TelescopeBorder",
        "TelescopeNormal",
        "BufferLineFill",
        "TreesitterContext",
      }
      for name, value in pairs(vim.log.levels) do
        if value ~= vim.log.levels.OFF then
          table.insert(extra_groups, "Notify" .. name .. "Body")
          table.insert(extra_groups, "Notify" .. name .. "Border")
        end
      end
      require("transparent").setup({ extra_groups = extra_groups })
    end,
    keys = {
      { "<leader>uB", "<cmd>TransparentToggle<cr>", { desc = "Toggle transparency" } },
    },
  },
  { -- [auto-dark-mode.nvim](https://github.com/f-person/auto-dark-mode.nvim)
    "f-person/auto-dark-mode.nvim",
    -- 在termux中无效禁止加载
    cond = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
    ---@module 'auto-dark-mode'
    ---@type AutoDarkModeOptions
    opts = {
      update_interval = 1000,
      set_dark_mode = function()
        vim.api.nvim_set_option_value("background", "dark", {})
      end,
      set_light_mode = function()
        vim.api.nvim_set_option_value("background", "light", {})
      end,
    },
  },
}
