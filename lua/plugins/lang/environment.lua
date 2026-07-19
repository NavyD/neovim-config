---@module 'lazy'
---@type LazySpec
return {
  {
    "misel",
    dir = vim.fs.joinpath(vim.fn.stdpath("config"), "local_plugins/misel"),
    dependencies = { "nvim-neotest/nvim-nio" },
    cond = vim.g.vscode ~= 1 and (vim.env.MISE_SHELL ~= nil or vim.fn.executable("mise") == 1),
    ---@type misel.EnvOpts
    opts = { load_env_immediately = vim.env.MISE_SHELL == nil },
  },
}
