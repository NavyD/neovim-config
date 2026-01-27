---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    ---@module 'lazyvim'
    ---@param opts lazyvim.TSConfig
    opts = function(_, opts)
      -- 从 lazyvim 中移除不再被 nvim-treesitter 支持的 jsonc，参考：
      -- fix(treesitter): remove deleted jsonc parser #6848
      -- https://github.com/LazyVim/LazyVim/pull/6848
      opts.ensure_installed = vim.tbl_filter(function(e)
        return e ~= "jsonc"
      end, opts.ensure_installed or {})
    end,
  },
}
