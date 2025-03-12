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
  { -- [Effortlessly embed images into any markup language, like LaTeX, Markdown](https://github.com/HakonHarnes/img-clip.nvim)
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
      default = {
        -- 默认保存 img 到当前打开文件所在目录
        dir_path = function()
          local curr_abs_dir = vim.fn.expand("%:p:h")
          return curr_abs_dir
        end,
        file_name = "%Y%m%d%H%M%S", ---@type string
      },
      -- [Overriding options for specific files, directories or custom triggers](https://github.com/HakonHarnes/img-clip.nvim#overriding-options-for-specific-files-directories-or-custom-triggers)
      -- dirs = {},
      -- files = {},
    },
    keys = {
      -- suggested keymap
      { "<leader>P", "<cmd>PasteImage<cr>", desc = "Paste image from system clipboard" },
    },
  },
  { -- [Bullets.vim is a Vim/NeoVim plugin for automated bullet lists](https://github.com/bullets-vim/bullets.vim)
    "bullets-vim/bullets.vim",
    -- NOTE: enable the plugin only for specific filetypes, if you don't do this,
    -- and you use the new snacks picker by folke, you won't be able to select a
    -- file with <CR> when in insert mode, only in normal mode
    -- https://github.com/folke/snacks.nvim/issues/812
    --
    -- This didn't work, added vim.g.bullets_enable_in_empty_buffers = 0 to
    -- ~/github/dotfiles-latest/neovim/neobean/init.lua
    -- ft = { "markdown", "text", "gitcommit", "scratch" },
    config = function()
      -- Disable deleting the last empty bullet when pressing <cr> or 'o'
      -- default = 1
      vim.g.bullets_delete_last_bullet_if_empty = 1

      -- 默认生效的类型
      vim.g.bullets_enabled_file_types = { "markdown", "text", "gitcommit", "scratch" }
    end,
  },
  { -- [About Easily insert and edit markdown tables using Neovim with a live preview and useful helpers](https://github.com/Myzel394/easytables.nvim)
    "Myzel394/easytables.nvim",
    ft = { "markdown", "text", "gitcommit" },
    config = function(_, opts)
      require("easytables").setup(opts or {})
    end,
  },
  {
    "stevearc/conform.nvim",
    ---@module 'conform'
    ---@param opts? conform.setupOpts
    opts = function(_, opts)
      if not opts then
        opts = { formatters_by_ft = { markdown = {} } }
      end
      if not opts.formatters_by_ft then
        opts.formatters_by_ft = { markdown = {} }
      end
      if not opts.formatters_by_ft.markdown then
        opts.formatters_by_ft.markdown = {}
      end

      local markdown_fmts = { "injected" }
      -- [A linter and formatter to help you to improve copywriting, correct spaces, words, and punctuations between CJK (Chinese, Japanese, Korean)](https://github.com/huacnlee/autocorrect)
      if vim.fn.executable("autocorrect") == 1 then
        table.insert(markdown_fmts, "autocorrect")
      end
      -- [conform.nvim: Injected language formatting (code blocks)](https://github.com/stevearc/conform.nvim/blob/master/doc/advanced_topics.md#injected-language-formatting-code-blocks)
      -- [injected](https://github.com/stevearc/conform.nvim/blob/master/doc/formatter_options.md#injected)
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.list_extend(opts.formatters_by_ft.markdown, markdown_fmts)
    end,
  },
  { "MeanderingProgrammer/render-markdown.nvim", enabled = false },
  {
    -- https://github.com/OXY2DEV/markview.nvim
    "OXY2DEV/markview.nvim",
    version = "*",
    lazy = false, -- Recommended
    -- https://github.com/LazyVim/LazyVim/blob/ec5981dfb1222c3bf246d9bcaa713d5cfa486fbd/lua/lazyvim/plugins/extras/lang/markdown.lua#L111C12-L111C61
    ft = { "markdown", "norg", "rmd", "org", "codecompanion" }, -- If you decide to lazy-load anyway
    dependencies = {
      -- FIXME: Tried to link bin "tree-sitter" to non-existent target "tree-sitter-windows-x64.exe".
      -- [Failed to install tree-sitter-cli on windows #7020](https://github.com/mason-org/mason-registry/issues/7020)
      -- [Requirements](https://github.com/OXY2DEV/markview.nvim#-requirements)
      {
        -- On windows/linux, you might need tree-sitter CLI for the latex parser
        "williamboman/mason.nvim",
        optional = true,
        ---@module 'mason'
        ---@type MasonSettings
        opts = {
          ensure_installed = { "tree-sitter-cli" },
        },
      },
      {
        "nvim-treesitter/nvim-treesitter",
        -- https://github.com/nvim-treesitter/nvim-treesitter/blob/master/lua/nvim-treesitter/configs.lua
        ---@module 'nvim-treesitter.configs'
        ---@type TSConfig
        ---@diagnostic disable-next-line: missing-fields
        opts = {
          ensure_installed = {
            "markdown",
            "markdown_inline",
            "html",
            "latex",
            "typst",
            "yaml",
          },
        },
        optional = true,
      },
      { "echasnovski/mini.icons" },
    },
    ---@module 'markview'
    ---@type mkv.config
    opts = {
      preview = {
        -- [linewise_hybrid_mode](https://github.com/OXY2DEV/markview.nvim/wiki/Preview-options#linewise_hybrid_mode)
        enable = true,
        -- debounce = 50,
        -- 使用混合模式[hybrid_modes](https://github.com/OXY2DEV/markview.nvim/wiki/Preview-options#hybrid_modes)
        hybrid_modes = { "n", "i", "nc", "c", "v", "s" },
        -- hybrid_modes = { "i", "c", "v", "s" },
        enable_hybrid_mode = true,
        -- linewise_hybrid_mode = true,
      },
      ---@diagnostic disable-next-line: missing-fields
      markdown = {
        -- https://github.com/OXY2DEV/markview.nvim/wiki/Markdown-options#list_items
        ---@diagnostic disable-next-line: missing-fields
        list_items = {
          enable = true,
          indent_size = 2,
          -- 默认为 4 会缩进太多
          shift_width = 2,
        },
      },
    },
    ---@param opts mkv.config
    config = function(_, opts)
      -- https://github.com/OXY2DEV/markview.nvim/wiki/Extra-modules#-extra-modules
      -- 使用 :Checkbox 修改 box 列表
      require("markview.extras.checkboxes").setup()
      -- 使用 `<c-a|x>` 增减 head 级别
      require("markview.extras.headings").setup()
      require("markview").setup(opts)
    end,
  },
}
