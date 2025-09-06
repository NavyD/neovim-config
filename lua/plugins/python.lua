-- 在 uv 项目中返回 PATH 中的 python 路径，否则返回 nil
---@return string|nil
local function get_py_binpath()
  if vim.uv.fs_stat("pyproject.toml") and vim.uv.fs_stat("uv.lock") then
    local py_bin = vim.fn.exepath("python")
    if py_bin ~= "" then
      return py_bin
    end
  end
  return nil
end

---@type LazyPluginSpec[]
return {
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        -- https://github.com/nvim-neotest/neotest-python
        ---@module 'neotest-python'
        ---@type neotest-python.AdapterConfig
        ["neotest-python"] = {
          runner = "pytest",
          -- If not provided, the path will be inferred by checking for
          -- virtual envs in the local directory and for Pipenev/Poetry configs
          python = get_py_binpath(),
        },
      },
    },
  },
  -- [bug: VenvSelect is now using main as the updated branch again. Please remove branch = regexp from your config. #6381](https://github.com/LazyVim/LazyVim/issues/6381#issuecomment-3241466459)
  {
    "linux-cultist/venv-selector.nvim",
    branch = "main",
    -- lazy = false,
    ft = "python",
    enabled = true,
    -- NOTE: venv-selector 源码中无 type
    opts = {
      -- [Default searches](https://github.com/linux-cultist/venv-selector.nvim#default-searches)
      search = {},
      -- [Global options to the plugin](https://github.com/linux-cultist/venv-selector.nvim#global-options-to-the-plugin)
      options = {
        on_venv_activate_callback = nil,
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      -- https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/dmypy.lua
      -- https://github.com/mfussenegger/nvim-lint#available-linters
      -- NOTE: 不使用 mason 安装 mypy 是因为通常 mypy 会被当前 py 项目安装
      linters_by_ft = {
        -- 使用 dmypy 代替 mypy 加速大型项目检查
        -- https://mypy.readthedocs.io/en/stable/mypy_daemon.html
        python = { "dmypy" },
      },
    },
  },
  {
    -- [How do I configure basedpyright? #3350](https://github.com/LazyVim/LazyVim/discussions/3350#discussioncomment-9584437)
    "neovim/nvim-lspconfig",
    opts = {
      ---@module "lspconfig.configs"
      ---@type lspconfig.options
      ---@diagnostic disable: missing-fields
      servers = {
        basedpyright = {
          settings = {
            basedpyright = {
              analysis = {
                -- [typeCheckingMode](https://docs.basedpyright.com/latest/benefits-over-pyright/better-defaults/#typecheckingmode)
                -- [basedpyright/pyright being very unreliable and reporting wrong information](https://www.reddit.com/r/neovim/comments/1bli209/basedpyrightpyright_being_very_unreliable_and/)
                -- 默认 recommend 会出现许多 warning
                typeCheckingMode = "standard",
              },
            },
          },
        },
      },
    },
  },
}
