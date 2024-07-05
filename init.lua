-- bootstrap lazy.nvim, LazyVim and your plugins
-- vscode-neovim Neovim configuration: https://github.com/vscode-neovim/vscode-neovim#neovim-configuration
if vim.g.vscode then
  -- vscode extension
else
  require("config.lazy")
end
