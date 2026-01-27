---@module 'lint'
-- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/linting.lua#L79
---@class LazyVimLinterCtx
---@field filename string

-- https://github.com/mfussenegger/nvim-lint/blob/ca6ea12daf0a4d92dc24c5c9ae22a1f0418ade37/lua/lint.lua#L157
---@class LazyVimLinter: lint.Linter
---@field condition fun(ctx: LazyVimLinterCtx):boolean

-- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/linting.lua#L7
---@class LazyVimLintOpts
---@field events? string[]
---@field linters_by_ft? table<string, string[]>
---@field linters? table<string, LazyVimLinter | fun():lint.Linter>

---@module 'lazyvim.plugins.lsp'
---@class LazyVimLspOpts: PluginLspOpts
---@field servers? table<string, lazyvim.lsp.Config|boolean>

---@module 'mason'
---@class LazyVimMasonOpts: MasonSettings
---@field ensure_installed? string[]

---@module 'lazy'
---@type LazyPluginSpec[]
return {
  { import = "plugins.lang" },
  { import = "plugins.editor" },
  { import = "plugins.ai" },
  {
    "mason-org/mason.nvim",
    -- https://github.com/mason-org/mason.nvim#default-configuration
    -- 在 lazyvim 中定义的类型，实现参考：
    -- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/lsp/init.lua#L279
    ---@type LazyVimMasonOpts
    opts = {
      github = {
        -- 默认 `https://github.com/%s/releases/download/%s/%s`
        -- 通常可配置为 `https://gh-proxy.com/https://github.com/%s/releases/download/%s/%s`
        download_url_template = vim.env.MASON_GITHUB_DOWNLOAD_URL_TEMPLATE,
      },
    },
  },
}
