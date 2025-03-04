---@type LazyPluginSpec[]
return {
  {
    -- https://github.com/jmbuhr/otter.nvim
    -- 为 markdown 等文档中的 codeblock 启用 LSP 补全
    "jmbuhr/otter.nvim",
    version = "*",
    event = "InsertEnter",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {},
    config = function(_, opts)
      local otter = require("otter")
      otter.setup(opts or {})

      -- 在进入编辑时激活，退出编辑时关闭避免 LSP 影响渲染
      local pat = { "*.markdown", "*.md" }
      vim.api.nvim_create_autocmd({ "FileType", "InsertEnter" }, {
        pattern = pat,
        callback = function()
          require("otter").activate()
        end,
      })
      -- InsertLeave 会在切换 buf 时频繁触发
      vim.api.nvim_create_autocmd({ "FileType", "InsertLeavePre", "BufLeave" }, {
        pattern = pat,
        callback = function()
          require("otter").deactivate()
        end,
      })
    end,
  },
  -- {
  --   "OXY2DEV/markview.nvim",
  --   lazy = false, -- Recommended
  --   ft = { "markdown", "codecompanion", "Avante" }, -- If you decide to lazy-load anyway
  --   dependencies = {
  --     "nvim-treesitter/nvim-treesitter",
  --     "nvim-tree/nvim-web-devicons",
  --   },
  -- },
}
