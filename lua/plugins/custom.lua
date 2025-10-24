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
  {
    "gbprod/yanky.nvim",
    -- 在termux中无效且可能会在打开文件时阻塞 禁止加载
    cond = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    keys = {
      -- 移动代码参数位置
      -- [Text objects: swap](https://github.com/nvim-treesitter/nvim-treesitter-textobjects/tree/main?tab=readme-ov-file#text-objects-swap)
      {
        "<leader>cpl",
        function()
          require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
        end,
        desc = "Swap parameter to next",
      },
      {
        "<leader>cph",
        function()
          require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
        end,
        desc = "Swap parameter to previous",
      },
      {
        "<leader>cpL",
        function()
          require("nvim-treesitter-textobjects.swap").swap_next("@parameter.outer")
        end,
        desc = "Swap out parameter to next",
      },
      {
        "<leader>cpH",
        function()
          require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.outer")
        end,
        desc = "Swap out parameter to previous",
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      local new_installeds = {
        -- [A CLI tool for code structural search, lint and rewriting](https://github.com/ast-grep/ast-grep)
        "ast-grep",
        "actionlint",
        "typos-lsp",
      }
      if vim.fn.executable("cargo") == 1 then
        -- 使用 mason 提供的最新版本
        vim.list_extend(new_installeds, { "rust-analyzer" })
      end
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, new_installeds)
    end,
  },
  {
    "folke/snacks.nvim",
    ---@type snacks.Config
    opts = {
      picker = {
        sources = {
          -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#files
          ---@type snacks.picker.files.Config
          ---@diagnostic disable-next-line: missing-fields
          files = {
            -- 默认显示隐藏文件
            hidden = true,
            ignored = false,
          },
          ---@type snacks.picker.explorer.Config
          ---@diagnostic disable-next-line: missing-fields
          explorer = {
            -- 默认显示隐藏文件
            hidden = true,
            ignored = false,
          },
          -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#notifications
          ---@type snacks.picker.notifications.Config
          ---@diagnostic disable-next-line: missing-fields
          notifications = {
            win = {
              preview = {
                wo = {
                  -- 查看通知的preview避免隐藏超出列长的部分
                  -- notifications 预览应该 wrap 避免无法查看全部或 item 被wrap
                  -- NOTE: 聚焦到 preview 上使用 `<a-w>`
                  -- editorconfig-checker-disable
                  -- 参考 [How to scroll preview panel in git log? #5523](https://github.com/LazyVim/LazyVim/discussions/5523#discussioncomment-12060745)
                  -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#snackspickeractionscycle_win
                  -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-config
                  -- editorconfig-checker-enable
                  wrap = true,
                },
              },
            },
          },
        },
      },
    },
    keys = {
      -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#zoxide
      {
        "<leader>fz",
        function()
          Snacks.picker.zoxide()
        end,
        mode = { "n", "x" },
        desc = "Zoxide",
      },
    },
  },
}
