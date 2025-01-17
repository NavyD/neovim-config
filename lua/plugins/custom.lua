---@type LazyPluginSpec
return {
  -- { "folke/noice.nvim", cond = not (vim.g.neovide or false) },
  {
    "lewis6991/gitsigns.nvim",
    -- https://github.com/lewis6991/gitsigns.nvim#installation--usage
    opts = {
      -- Toggle with `:Gitsigns toggle_current_line_blame`
      -- 启用git blame line
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
      },
    },
  },
  -- 禁用init 避免在打开cz文件时卡顿
  { "xvzc/chezmoi.nvim", enabled = true, init = function() end },
  {
    "gbprod/yanky.nvim",
    -- 在termux中无效且可能会在打开文件时阻塞 禁止加载
    cond = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
  },
  {
    "nvim-treesitter/nvim-treesitter",
    -- 扩展默认的配置参考https://www.lazyvim.org/configuration/plugins#%EF%B8%8F-customizing-plugin-specs
    -- opts是由之前定义的table，可以配置func修改添加新的
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, { "powershell", "gotmpl" })
    end,
  },
}
