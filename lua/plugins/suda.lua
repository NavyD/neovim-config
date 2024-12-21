return {
  {
    -- [suda is a plugin to read or write files with sudo command](https://github.com/lambdalisue/vim-suda)
    "lambdalisue/suda.vim",
    init = function()
      -- 自动读写需要的使用sudo的文件 https://github.com/lambdalisue/vim-suda#smart-edit
      vim.g.suda_smart_edit = 1
    end,
  },
}
