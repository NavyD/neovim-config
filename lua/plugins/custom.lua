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
  {
    "xvzc/chezmoi.nvim",
    enabled = true,
    dependencies = {
      { "nvim-neotest/nvim-nio" },
    },
    init = function()
      require("nio").run(function()
        -- 获取 cz 实际的源目录
        local cz_src_sc = require("utils.process").run_co({ "chezmoi", "source-path" }, { text = true })
        -- fix: 在windows上无HOME变量导致nil连接str出错
        local sc_src_path =
          vim.fs.joinpath(os.getenv(jit.os == "Windows" and "USERPROFILE" or "HOME"), ".local/share/chezmoi")
        if cz_src_sc.code ~= 0 then
          vim.notify(
            "Fallback chezmoi source path to " .. sc_src_path .. " by error: " .. (cz_src_sc.stderr or ""),
            vim.log.levels.WARN
          )
        else
          sc_src_path = vim.trim(cz_src_sc.stdout)
          -- vim.notify("Got chezmoi source path " .. sc_src_path .. " in " .. vim.uv.cwd(), vim.log.levels.INFO)
        end
        vim.schedule(function()
          vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
            pattern = { vim.fs.joinpath(sc_src_path, "*") },
            callback = function(ev)
              local bufnr = ev.buf
              local edit_watch = function()
                require("chezmoi.commands.__edit").watch(bufnr)
              end
              vim.schedule(edit_watch)
            end,
          })
        end)
      end)
    end,
  },
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
}
