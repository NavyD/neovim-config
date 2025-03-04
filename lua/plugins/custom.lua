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
  -- { "folke/noice.nvim", cond = not (vim.g.neovide or false) },
  {
    "lewis6991/gitsigns.nvim",
    -- https://github.com/lewis6991/gitsigns.nvim#installation--usage
    ---@module 'gitsigns'
    ---@class Gitsigns.Config
    opts = {
      -- Toggle with `:Gitsigns toggle_current_line_blame`
      -- 启用git blame line
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
      },
    },
  },
  -- 禁用init 避免在打开cz文件时卡顿
  { "xvzc/chezmoi.nvim", enabled = true, init = function() end },
  {
    "gbprod/yanky.nvim",
    -- 在termux中无效且可能会在打开文件时阻塞 禁止加载
    cond = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
  },
  {
    "nvim-treesitter/nvim-treesitter",
    ---@module 'nvim-treesitter'
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      -- https://github.com/nvim-treesitter/nvim-treesitter#supported-languages
      ensure_installed = {
        "powershell",
        "gotmpl",
        "ssh_config",
        "nginx",
        "properties",
        "csv",
        "jinja",
        "jinja_inline",
        "ini",
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      textobjects = {
        -- 移动代码参数位置
        -- [Text objects: swap](https://github.com/nvim-treesitter/nvim-treesitter-textobjects#text-objects-swap)
        swap = {
          enable = true,
          swap_next = {
            ["<leader>a"] = "@parameter.inner",
          },
          swap_previous = {
            ["<leader>A"] = "@parameter.inner",
          },
        },
      },
    },
  },
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      local new_installeds = {
        -- [A CLI tool for code structural search, lint and rewriting](https://github.com/ast-grep/ast-grep)
        "ast-grep",
        "shellcheck",
        "shfmt",
        "actionlint",
        "typos-lsp",
      }
      if vim.fn.executable("pwsh") == 1 then
        -- 仅在存在 pwsh 时才会运行 pwsh 启动 LSP 服务
        vim.list_extend(new_installeds, { "powershell-editor-services" })
      end
      if vim.fn.executable("cargo") == 1 then
        -- 使用 mason 提供的最新版本
        vim.list_extend(new_installeds, { "rust-analyzer" })
      end
      opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, new_installeds)
    end,
  },
  {
    "folke/snacks.nvim",
    keys = {
      -- https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#zoxide
      {
        "<leader>fz",
        function()
          Snacks.picker.zoxide()
        end,
        mode = { "n", "x" },
        desc = "Zoxide",
      },
    },
  },
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
}
