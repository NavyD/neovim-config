---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    -- First class powershell editor integration into Neovim
    -- https://github.com/TheLeoP/powershell.nvim
    "TheLeoP/powershell.nvim",
    ft = "ps1",
    -- 仅在存在 pwsh 时才会运行 pwsh 启动 LSP 服务
    -- 最好使用 pwsh 7+ https://github.com/PowerShell/PowerShellEditorServices#supported-powershell-versions
    cond = vim.fn.executable("pwsh") == 1,
    dependencies = {
      "mason-org/mason.nvim",
      ---@type LazyVimMasonOpts
      opts = { ensure_installed = { "powershell-editor-services" } },
    },
    ---@module 'powershell'
    ---@type powershell.user_config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      settings = {
        powershell = {
          codeFormatting = {
            -- 默认与 vscode-powershell 格式化保持一致，可以通过 neoconf.nvim
            -- 读取项目级别中的 .vscode/settings.json 覆盖配置
            openBraceOnSameLine = true,
            newLineAfterCloseBrace = true,
          },
        },
      },
    },
    ---@param opts powershell.user_config
    config = function(_, opts)
      if not opts.bundle_path then
        -- Programmatically get the path for installations #33
        -- https://github.com/mason-org/mason.nvim/discussions/33#discussioncomment-14936037
        -- NOTE: $MASON 环境变量需要 mason 插件加载才有效
        local mason_root = vim.env.MASON or require("mason.settings").current.install_root_dir
        if not mason_root then
          vim.notify("Not found mason root for powershell-editor-services", vim.log.levels.ERROR)
          return
        end
        opts.bundle_path = vim.fs.joinpath(mason_root, "packages/powershell-editor-services")
      end
      require("powershell").setup(opts)
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    ---@type lazyvim.TSConfig
    opts = { ensure_installed = { "powershell" } },
  },
  -- {
  --   "neovim/nvim-lspconfig",
  --   -- lspconfig lazy 相关配置参考： https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/lang/yaml.lua
  --   -- https://www.lazyvim.org/plugins/lsp#nvim-lspconfig
  --   ---@type LazyVimLspOpts
  --   opts = {
  --     servers = {
  --       powershell_es = {
  --         settings = {
  --           powershell = {
  --             codeFormatting = {
  --               -- 默认与 vscode-powershell 格式化保持一致，可以通过 neoconf.nvim
  --               -- 读取项目级别中的 .vscode/settings.json 覆盖配置
  --               openBraceOnSameLine = true,
  --               newLineAfterCloseBrace = true,
  --             },
  --           },
  --         },
  --       },
  --     },
  --   },
  -- },
}
