-- ansible 不支持 windows 平台作为控制节点
if vim.fn.has("win32") == 1 then
  return {}
end

-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/lang/ansible.lua
---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "mason-org/mason.nvim",
    ---@type LazyVimMasonOpts
    opts = { ensure_installed = { "ansible-lint" } },
  },
  {
    "neovim/nvim-lspconfig",
    ---@type LazyVimLspOpts
    opts = {
      servers = {
        ansiblels = {},
      },
    },
  },
  {
    "mfussenegger/nvim-ansible",
    ft = { "yaml" },
    keys = {
      {
        "<leader>ta",
        function()
          require("ansible").run()
        end,
        ft = "yaml.ansible",
        desc = "Ansible Run Playbook/Role",
        silent = true,
      },
    },
  },
  -- 添加 ansible lint
  {
    "mfussenegger/nvim-lint",
    ---@type LazyVimLintOpts
    opts = {
      linters_by_ft = {
        ["yaml.ansible"] = { "ansible_lint" },
      },
    },
  },
  {
    "ph1losof/ecolog.nvim",
    optional = true,
    ---@type EcologConfigExt
    ---@diagnostic disable-next-line:missing-fields
    opts = {
      providers = {
        {
          pattern = "ansible_facts%.env%.[%w_]*",
          filetype = { "yaml.ansible" },
          extract_var = function(line, col)
            return require("ecolog.utils").extract_env_var(line, col, "ansible_facts%.env%.([%w_]*)")
          end,
          get_completion_trigger = function()
            return "ansible_facts.env."
          end,
        },
      },
    },
  },
}
