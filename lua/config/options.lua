-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- disable autoformat global
-- use `<leader>uf` to toggle autoformat
-- [Disable autoformat for some buffers](https://www.lazyvim.org/configuration/tips#disable-autoformat-for-some-buffers)
vim.g.autoformat = false

-- [Unable to copy text from lazyvim running in remote ssh host to host clipboard #4602](https://github.com/LazyVim/LazyVim/discussions/4602)
-- 参考：https://github.com/cameronr/kickstart-modular.nvim/blob/master/lua/options.lua
-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard:append("unnamedplus")

  -- Fix "waiting for osc52 response from terminal" message
  -- https://github.com/neovim/neovim/issues/28611

  if vim.env.SSH_TTY ~= nil then
    -- Set up clipboard for ssh

    local function my_paste(_)
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
        ["+"] = my_paste("+"),
        ["*"] = my_paste("*"),
      },
    }
  end
end)

-- 在win上配置默认使用pwsh
-- 参考: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
if jit.os == "Windows" then
  local win_sh = nil
  if vim.fn.executable("pwsh") then
    -- [options.lua recommendation for terminal shell on Windows for pwsh should be "pwsh.exe" now #4805](https://github.com/LazyVim/LazyVim/issues/4805)
    win_sh = "pwsh.exe"
  elseif vim.fn.executable("powershell") then
    win_sh = "powershell.exe"
  end
  if win_sh then
    LazyVim.terminal.setup(win_sh)
  end
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
