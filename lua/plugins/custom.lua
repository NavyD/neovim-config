---@type LazyPluginSpec[]
return {
  -- { "folke/noice.nvim", cond = not (vim.g.neovide or false) },
  {
    "lewis6991/gitsigns.nvim",
    -- https://github.com/lewis6991/gitsigns.nvim#installation--usage
    ---@module 'gitsigns'
    ---@class Gitsigns.Config
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
    -- 扩展默认的配置参考 https://www.lazyvim.org/configuration/plugins#%EF%B8%8F-customizing-plugin-specs
    -- opts是由之前定义的table，可以配置func修改添加新的
    ---@module 'nvim-treesitter'
    ---@param opts TSConfig
    opts = function(_, opts)
      local new_installeds = { "powershell", "gotmpl" }
      local installed = opts.ensure_installed
      if type(installed) == "table" then
        vim.list_extend(installed, new_installeds)
      else
        table.insert(new_installeds, installed)
        opts.ensure_installed = new_installeds
      end
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      textobjects = {
        -- 移动代码参数位置
        -- [Text objects: swap](https://github.com/nvim-treesitter/nvim-treesitter-textobjects#text-objects-swap)
        swap = {
          enable = true,
          swap_next = {
            ["<leader>a"] = "@parameter.inner",
          },
          swap_previous = {
            ["<leader>A"] = "@parameter.inner",
          },
        },
      },
    },
  },
}
