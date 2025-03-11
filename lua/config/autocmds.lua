-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- [how to disable spellcheck in markdown file? #4021](https://github.com/LazyVim/LazyVim/discussions/4021)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.spell = false

    -- 检查 markview 是否被加载
    if package.loaded.markview then
      -- It is recommended to use nowrap(though there is wrap support in the plugin) & expandtab.
      -- https://github.com/OXY2DEV/markview.nvim#-requirements
      vim.opt_local.wrap = false
      vim.opt_local.expandtab = true
    end
  end,
})
