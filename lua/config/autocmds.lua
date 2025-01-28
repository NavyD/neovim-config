-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- [how to disable spellcheck in markdown file? #4021](https://github.com/LazyVim/LazyVim/discussions/4021)
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text" },
    callback = function()
      vim.opt_local.spell = false
    end,
})

