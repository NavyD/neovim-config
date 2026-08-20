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
      {
        "<leader>uB",
        "<cmd>TransparentToggle<cr>",
        { desc = "Toggle transparency" },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    optional = true,
    ---@type LazyVimConfig
    opts = {
      -- 在启动后首次执行 `colorscheme catppuccin-latte` 等主题切换后 bufferline
      -- 颜色未改变，再次 colorscheme 切换才会生效。这可能是 tokyonight,catppuccin
      -- 需要专门适配，所以这里不会覆盖原 lazyvim 的主题配置
      --- FIXME: [Bug]: highlights are not fully reloaded on ColorScheme autocmd
      --- https://github.com/akinsho/bufferline.nvim/issues/1030
      colorscheme = function()
        -- 移除 lazyvim 的主题配置，让 autotheme,auto-dark-mode 配置
        -- require("tokyonight").load()

        -- 在首次切换主题时检查，如果是 catppuccin 类型的主题则再次切换修复
        -- bufferline 的高亮问题
        vim.api.nvim_create_autocmd("ColorScheme", {
          -- 只执行一次
          once = true,
          callback = function(args)
            -- NOTE: 如果有其它主题也无法在启动时首次切换主题无法设置 bufferline
            -- 的高亮，可以根据需要扩展任意主题
            if not args.match:match("^catppuccin") then
              return
            end
            vim.schedule(function()
              local ok, res = pcall(vim.cmd.colorscheme, args.match)
              if not ok then
                vim.notify(
                  string.format(
                    "failed to run `colorscheme %s` by error: %s",
                    args.match,
                    res
                  ),
                  vim.log.levels.ERROR
                )
              end
            end)
          end,
        })

        -- NOTE: ai 的解决方案
        -- 原理：切换前组已被清除 → 主题加载后 ColorScheme 事件中 bufferline
        -- 设置成功（组不存在）；后续切换主题自身 hi clear 兜底，清除幂等无害；
        -- transparent.nvim 的 BufferLineFill 透明不受影响（其在
        -- ColorScheme 事件中强制设置）。
        -- vim.api.nvim_create_autocmd("ColorSchemePre", {
        --   callback = function()
        --     for _, name in
        --       ipairs(vim.fn.getcompletion("BufferLine*", "highlight"))
        --     do
        --       vim.api.nvim_set_hl(0, name, {})
        --     end
        --   end,
        -- })
      end,
    },
  },
  {
    dir = vim.fs.joinpath(vim.fn.stdpath("config"), "local_plugins/autotheme"),
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
