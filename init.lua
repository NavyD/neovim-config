-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
if vim.g.vscode ~= 1 then
  require("utils.redir")
end
