---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    -- Modular nvim codelens support with inline references, git blame and more
    -- https://github.com/oribarilan/lensline.nvim
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
  },
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    -- 在 VimEnter 事件后优先加载
    event = "VeryLazy",
    priority = 1000,
    ---@module 'tiny-inline-diagnostic'
    ---@type PluginConfig
    ---@diagnostic disable: missing-fields
    opts = {
      -- https://github.com/rachartier/tiny-inline-diagnostic.nvim/#configuration
      options = {
        -- Display the source of the diagnostic (e.g., basedpyright, vsserver, lua_ls etc.)
        show_source = {
          enabled = true,
          if_many = false,
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
    },
  },
  {
    "neovim/nvim-lspconfig",
    optional = true,
    -- This disables Neovim's built-in virtual text diagnostics to prevent conflicts and duplicate displays. The plugin provides its own inline diagnostic display.
    -- https://github.com/rachartier/tiny-inline-diagnostic.nvim/#lazyvim
    opts = { diagnostics = { virtual_text = false } },
  },
  {
    -- A Neovim plugin that provides a simple way to run and visualize code actions with Telescope.
    -- https://github.com/rachartier/tiny-code-action.nvim
    "rachartier/tiny-code-action.nvim",
    dependencies = {
      { "nvim-lua/plenary.nvim" },
      { "nvim-telescope/telescope.nvim", optional = true },
      { "ibhagwan/fzf-lua", optional = true },
      {
        "folke/snacks.nvim",
        optional = true,
        opts = { terminal = {} },
      },
      {
        "neovim/nvim-lspconfig",
        optional = true,
        ---@type LazyVimLspOpts
        opts = {
          servers = {
            ["*"] = {
              -- 必须在 lspconfig 中覆盖，否则无效
              -- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/lsp/init.lua#L88C15-L88C120
              keys = {
                {
                  "<leader>ca",
                  function()
                    require("tiny-code-action").code_action({})
                  end,
                  desc = "Tiny Code Action",
                  mode = { "n", "x" },
                  has = "codeAction",
                },
              },
            },
          },
        },
      },
    },
    event = "LspAttach",
    opts = {
      -- https://github.com/rachartier/tiny-code-action.nvim#options
      -- 默认使用 difft/delta/vim
      backend = vim.fn.executable("difft") == 1 and "difftastic"
        or (vim.fn.executable("delta") == 1 and "delta" or "vim"),
    },
  },
}
