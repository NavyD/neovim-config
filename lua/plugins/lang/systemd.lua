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

local os_uname = vim.uv.os_uname()
-- 由于 systemd-lsp 未预编译 linux aarch64，所以不支持从 mason 下载
local systemd_lsp_enabled = os_uname.sysname ~= "Linux"
  or os_uname.machine ~= "aarch64"
  -- 注意在 wsl 中耗时可达 80ms
  -- executable() is slow on WSL
  -- https://github.com/neovim/neovim/issues/31506
  or vim.fn.executable("systemd-lsp") == 1

---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    -- syntax highlighting and filetype detection for systemd unit files
    -- https://github.com/wgwoods/vim-systemd-syntax
    "wgwoods/vim-systemd-syntax",
  },
  {
    "neovim/nvim-lspconfig",
    ---@type LazyVimLspOpts
    opts = not systemd_lsp_enabled and {} or {
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
    ---@type LazyVimMasonOpts
    opts = { ensure_installed = { "systemdlint" } },
  },
  {
    "mfussenegger/nvim-lint",
    ---@type LazyVimLintOpts
    opts = {
      linters_by_ft = {
        systemd = { "systemdlint", "systemd-analyze" },
      },
    },
  },
}
