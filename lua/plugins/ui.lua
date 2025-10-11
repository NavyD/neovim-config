---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    config = function()
      -- https://github.com/rachartier/tiny-inline-diagnostic.nvim/#configuration
      require("tiny-inline-diagnostic").setup({
        options = {
          -- Display the source of the diagnostic (e.g., basedpyright, vsserver, lua_ls etc.)
          show_source = {
            enabled = true,
            if_many = true,
          },
          -- Configuration for multiline diagnostics
          -- Can be a boolean or a table with detailed options
          multilines = {
            enabled = true,
          },
          -- Events to attach diagnostics to buffers
          -- Default: { "LspAttach" }
          -- Only change if the plugin doesn't work with your configuration
          -- editorconfig-checker-disable-next-line
          -- [Diagnostics not shown from nvim-lint #40](https://github.com/rachartier/tiny-inline-diagnostic.nvim/issues/40#issuecomment-2331128814)
          -- overwrite_events = { "DiagnosticChanged", "BufEnter" },
        },
      })
      vim.diagnostic.config({ virtual_text = false }) -- Disable default virtual text
    end,
  },
  {
    -- editorconfig-checker-disable-next-line
    -- [Modular nvim codelens support with inline references, git blame and more](https://github.com/oribarilan/lensline.nvim)
    "oribarilan/lensline.nvim",
    version = "*", -- or: branch = 'release/1.x' for latest non-breaking updates
    event = "LspAttach",
    opts = {
      profiles = {
        {
          name = "minimal",
          style = {
            placement = "inline",
            prefix = "",
            -- render = "focused", -- optionally render lenses only for focused function
          },
        },
      },
    },
    -- config = function()
    --   require("lensline").setup()
    -- end,
  },
  {
    "nvim-mini/mini.animate",
    optional = true,
    -- NOTE: 在 vscode 中禁用避免滚动出问题，使用 `vscode=true` 无效
    cond = vim.g.neovide == nil and vim.g.vscode == nil,
  },
  {
    "m4xshen/smartcolumn.nvim",
    -- https://github.com/m4xshen/smartcolumn.nvim#-configuration
    opts = {
      -- 默认不显示，仅当存在 editorconfig 时自动启用
      colorcolumn = "0",
      disabled_filetypes = {
        "alpha",
        "calendar",
        "help",
        "text",
        -- "markdown",
        "NvimTree",
        "lazy",
        "mason",
        "help",
        "checkhealth",
        "lspinfo",
        -- typos: disable-next-line
        "noice",
        "Trouble",
        "fish",
        "zsh",
      },
      scope = "file",
      editorconfig = true,
    },
  },
}
