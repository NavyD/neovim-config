---@type LazySpec
return {
  {
    -- [Remove all background colors to make nvim transparent](https://github.com/xiyaowong/transparent.nvim)
    "xiyaowong/transparent.nvim",
    -- Avoid lazy-loading this plugin to ensure the highlight-clearing logic is triggered. The plugin's function runs quickly.
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
  -- {
  --   "LazyVim/LazyVim",
  --   optional = true,
  --   ---@type LazyVimConfig
  --   opts = {
  --     -- 在启动后首次执行 `colorscheme catppuccin-latte` 等主题切换后 bufferline
  --     -- 颜色未改变，再次 colorscheme 切换才会生效。这可能是 tokyonight,catppuccin
  --     -- 需要专门适配，所以这里不会覆盖原 lazyvim 的主题配置
  --     --- FIXME: [Bug]: highlights are not fully reloaded on ColorScheme autocmd
  --     --- https://github.com/akinsho/bufferline.nvim/issues/1030
  --     -- colorscheme = function()
  --     --   require("tokyonight").load()
  --     -- end,
  --   },
  -- },
  {
    dir = vim.fs.joinpath(vim.fn.stdpath("config"), "lua/utils/autotheme"),
    dependencies = { "nvim-neotest/nvim-nio" },
    lazy = false,
    opts = {},
  },
  { -- [auto-dark-mode.nvim](https://github.com/f-person/auto-dark-mode.nvim)
    "f-person/auto-dark-mode.nvim",
    event = "VeryLazy",
    -- 在termux中无效禁止加载
    -- cond = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
    ---@module 'auto-dark-mode'
    ---@type AutoDarkModeOptions
    opts = {
      update_interval = 3000,
      set_dark_mode = function()
        require("autotheme").set_theme("dark")
        -- vim.api.nvim_set_option_value("background", "dark", {})
      end,
      set_light_mode = function()
        require("autotheme").set_theme("light")
        -- vim.api.nvim_set_option_value("background", "light", {})
      end,
    },
  },
}
