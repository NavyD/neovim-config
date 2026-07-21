---@module 'lint'
-- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/linting.lua#L79
---@class LazyVimLinterCtx
---@field filename string
---@field dirname string

-- https://github.com/mfussenegger/nvim-lint/blob/ca6ea12daf0a4d92dc24c5c9ae22a1f0418ade37/lua/lint.lua#L157
---@class LazyVimLinter: lint.Linter
---@field condition? fun(ctx: LazyVimLinterCtx):boolean
---@field prepend_args string[]?

-- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/linting.lua#L7
---@alias LazyVimLintOptsFtLinters string[] | { [integer]: string, _compound_ft: boolean?}
---@class LazyVimLintOpts
---@field events? string[]
---@field linters_by_ft? table<string, LazyVimLintOptsFtLinters>
---@field linters? table<string, LazyVimLinter | fun():lint.Linter>
---#配置 linter 注意是以 linter 名而非 filetype 如对于 yaml 使用 yamllint 时配置为 `{linters={yamllint={}}}`

---@module 'lazyvim.plugins.lsp'
---@class LazyVimLspOpts: PluginLspOpts
---@field servers? table<string, lazyvim.lsp.Config|boolean>
---@field setup? table<string, fun(server:string, opts: vim.lsp.Config):boolean?>

---@module 'mason'
---@class LazyVimMasonOpts: MasonSettings
---@field ensure_installed? string[]

---@module 'lazy'
---@type LazyPluginSpec[]
return {
  { import = "plugins.lang" },
  { import = "plugins.editor" },
  { import = "plugins.ai" },
}
