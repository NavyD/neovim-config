---@module 'lazy'
---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    opts_extend = { "servers.harper_ls.filetypes" },
    ---@type LazyVimLspOpts
    opts = {
      servers = {
        -- Offline, privacy-first grammar checker. Fast, open-source, Rust-powered
        -- https://github.com/automattic/harper
        harper_ls = {
          -- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/configs/harper_ls.lua
          filetypes = { "text" }, -- WARN: 无法检查 yaml 类型
          -- https://writewithharper.com/docs/integrations/neovim#Optional-Configuration
          settings = {
            ["harper-ls"] = {
              linters = {
                SentenceCapitalization = false,
                SpellCheck = false,
              },
            },
          },
        },
        -- Source code spell checker for Visual Studio Code, Neovim and other LSP clients.
        -- https://github.com/tekumara/typos-lsp
        typos_lsp = {
          -- https://github.com/neovim/nvim-lspconfig/blob/master/lsp/typos_lsp.lua
          -- https://github.com/tekumara/typos-lsp/blob/main/docs/neovim-lsp-config.md
          settings = {},
        },
      },
      -- 允许在启动前修改 opts.servers.any_ls 的配置内容，fun 返回 true 表示不通过 lspconfig 配置
      -- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/lsp/init.lua#L140
      -- NOTE: 保留配置方式可以以后参考
      setup = {
        -- 参考：https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/lsp/init.lua#L244
        -- harper_ls = function(_, opts)
        --   -- 允许扩展定义的配置 `opts.servers.harper_ls.filetypes` 与默认的 lspconfig 配置
        --   -- `vim.lsp.config.harper_ls.filetypes` 合并
        --   if vim.islist(opts.filetypes) then
        --     vim.list_extend(opts.filetypes, vim.lsp.config.harper_ls.filetypes or {})
        --   end
        --   -- 仍然使用 lspconfig 的预配置
        --   return false
        -- end,
      },
    },
  },
  {
    -- A Neovim plugin that creates a hex editing mode.
    -- https://github.com/DamianVCechov/hexview.nvim
    "DamianVCechov/hexview.nvim",
    opts = {},
  },
}
