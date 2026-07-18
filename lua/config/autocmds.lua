-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local api = vim.api

local augroup = api.nvim_create_augroup("my_autocmds", { clear = true })

-- [how to disable spellcheck in markdown file? #4021](https://github.com/LazyVim/LazyVim/discussions/4021)
api.nvim_create_autocmd("FileType", {
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  group = augroup,
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

if vim.o.exrc then
  -- 在 :w 或 :10,20w 触发
  api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
    pattern = { ".nvim.lua", ".nvimrc", ".exrc" },
    group = augroup,
    ---@param args vim.api.keyset.create_autocmd.callback_args
    callback = vim.schedule_wrap(function(args)
      if vim.bo.buftype ~= "" then
        return
      end
      local filename = vim.fs.relpath(vim.fn.getcwd(), args.file)
      -- 该 buf 文件必须在 $cwd/ 下
      if not filename or vim.fs.basename(filename) ~= filename then
        return
      end
      vim.cmd("trust")
    end),
  })
end
