---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    -- Context-aware paste indentation for Neovim. Pasted code lands at the correct indent level, every time, in every language.
    -- https://github.com/nemanjamalesija/smart-paste.nvim
    "nemanjamalesija/smart-paste.nvim",
    event = "VeryLazy",
    config = true,
  },
}
