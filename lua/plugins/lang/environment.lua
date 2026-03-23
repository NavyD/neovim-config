---@module 'lazy'
---@type LazySpec
return {
  {
    "misel",
    dir = vim.fs.joinpath(vim.fn.stdpath("config"), "lua/utils"),
    dependencies = { "nvim-neotest/nvim-nio" },
    lazy = true,
    event = "VeryLazy",
    cond = vim.g.vscode ~= 1 and vim.fn.executable("mise") == 1,
    ---@type misel.EnvOpts
    opts = { load_env_immediately = vim.env.MISE_SHELL == nil },
  },
}
