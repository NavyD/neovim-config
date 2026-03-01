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
    "mason-org/mason.nvim",
    opts = function(_, opts)
      local new_installeds = {
        -- [A CLI tool for code structural search, lint and rewriting](https://github.com/ast-grep/ast-grep)
        "ast-grep",
        "actionlint",
      }
      if vim.fn.executable("cargo") == 1 then
        -- 使用 mason 提供的最新版本
        vim.list_extend(new_installeds, { "rust-analyzer" })
      end
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, new_installeds)
    end,
  },
}
