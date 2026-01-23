-- 添加文件类型关联 systemd 以自动配置 filetype=systemd 激活 lsp，参考 lazyvim 的配置
-- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/extras/lang/markdown.lua#L2
-- 也可以创建 `ftdetect/systemd.lua` 实现。
-- systemd_lsp 配置参考：feat(systemd_lsp): Update functionality and add extra documentation. #4252
-- https://github.com/neovim/nvim-lspconfig/pull/4252
vim.filetype.add({
  extension = {
    -- systemd unit filetypes
    service = "systemd",
    socket = "systemd",
    timer = "systemd",
    mount = "systemd",
    automount = "systemd",
    swap = "systemd",
    target = "systemd",
    path = "systemd",
    slice = "systemd",
    scope = "systemd",
    device = "systemd",
    -- Podman Quadlet filetypes
    container = "systemd",
    volume = "systemd",
    network = "systemd",
    kube = "systemd",
    pod = "systemd",
    build = "systemd",
    image = "systemd",
  },
})
---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "neovim/nvim-lspconfig",
    ---@module 'lazyvim'
    ---@type PluginLspOpts
    opts = {
      ---@type table<string, lazyvim.lsp.Config|boolean>
      servers = {
        -- language server for systemd unit files - embedded documentation + complete LSP implementation in rust.
        -- https://github.com/JFryy/systemd-lsp
        systemd_lsp = {
          root_dir = function(bufnr, on_dir)
            local fname = vim.api.nvim_buf_get_name(bufnr)

            local systemd_unit_filetypes = { -- Credit to @magnuslarsen
              -- systemd unit files
              "*.service",
              "*.socket",
              "*.timer",
              "*.mount",
              "*.automount",
              "*.swap",
              "*.target",
              "*.path",
              "*.slice",
              "*.scope",
              "*.device",
              -- Podman Quadlet files
              "*.container",
              "*.volume",
              "*.network",
              "*.kube",
              "*.pod",
              "*.build",
              "*.image",
            }

            local util = require("lspconfig.util")

            on_dir((util.root_pattern(systemd_unit_filetypes))(fname))
          end,
        },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    -- Systemd Linter
    -- https://github.com/priv-kweihmann/systemdlint
    opts = { ensure_installed = { "systemdlint" } },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        systemd = { "systemdlint", "systemd-analyze" },
      },
    },
  },
}
