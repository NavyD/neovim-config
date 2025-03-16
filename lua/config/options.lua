-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- disable autoformat global
-- use `<leader>uf` to toggle autoformat
-- [Disable autoformat for some buffers](https://www.lazyvim.org/configuration/tips#disable-autoformat-for-some-buffers)
vim.g.autoformat = false

-- [How do I configure basedpyright? #3350](https://github.com/LazyVim/LazyVim/discussions/3350#discussioncomment-9865324)
-- https://github.com/LazyVim/LazyVim/blob/ec5981dfb1222c3bf246d9bcaa713d5cfa486fbd/lua/lazyvim/plugins/extras/lang/python.lua#L72
vim.g.lazyvim_python_lsp = "basedpyright"

-- fix: 在windows上无HOME变量导致nil连接str出错
-- lazy/LazyVim/lua/lazyvim/plugins/extras/util/chezmoi.lua:60: attempt to concatenate a nil value
-- lazy/LazyVim/lua/lazyvim/plugins/extras/util/chezmoi.lua:31: attempt to concatenate a nil value
if jit.os == "Windows" then
  -- NOTE: 不能是`C:\Users\xxxuser`，会导致lua连接成的path str 可能无法被找到
  -- 如果是`\`类型将会无法触发create_autocmd edit
  vim.env.HOME = os.getenv("USERPROFILE"):gsub("\\", "/")
end

-- Fix "waiting for osc52 response from terminal" message
-- https://github.com/neovim/neovim/issues/28611
-- Set up clipboard for ssh
if vim.env.SSH_TTY ~= nil then
  -- [Unable to copy text from lazyvim running in remote ssh host to host clipboard #4602](https://github.com/LazyVim/LazyVim/discussions/4602)
  -- 参考：https://github.com/cameronr/kickstart-modular.nvim/blob/master/lua/options.lua
  -- Sync clipboard between OS and Neovim.
  --  Schedule the setting after `UiEnter` because it can increase startup-time.
  --  Remove this option if you want your OS clipboard to remain independent.
  --  See `:help 'clipboard'`
  vim.opt.clipboard = "unnamedplus"
  vim.schedule(function()
    local function reg_paste_fn(_)
      return function(_)
        local content = vim.fn.getreg('"')
        return vim.split(content, "\n")
      end
    end

    vim.g.clipboard = {
      name = "OSC 52",
      copy = {
        ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
        ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
      },
      paste = {
        -- No OSC52 paste action since wezterm doesn't support it
        -- Should still paste from nvim
        ["+"] = reg_paste_fn("+"),
        ["*"] = reg_paste_fn("*"),
      },
    }
  end)
end

-- 在win上配置默认使用pwsh
-- 参考: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/util/terminal.lua
if jit.os == "Windows" then
  -- shell=pwsh/powershell无区别，会优先考虑pwsh
  LazyVim.terminal.setup("pwsh")
  -- vim.o.shell = "C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
  -- vim.o.shell = '"C:\\Program Files\\PowerShell\\7\\pwsh.exe"'
end

-- [No Nonsense Neovim Client in Rust](https://github.com/neovide/neovide)
-- [neovide configuration](https://neovide.dev/configuration.html)
if vim.g.neovide then
  vim.o.guifont = "Cascadia Mono,Sarasa Mono SC"

  -- [How Can I Dynamically Change The Scale At Runtime?](https://neovide.dev/faq.html#how-can-i-dynamically-change-the-scale-at-runtime)
  vim.g.neovide_scale_factor = 0.8 -- default 1
  local change_scale_factor = function(delta)
    vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
  end
  vim.keymap.set("n", "<C-=>", function()
    change_scale_factor(1.25)
  end)
  vim.keymap.set("n", "<C-->", function()
    change_scale_factor(1 / 1.25)
  end)
end
