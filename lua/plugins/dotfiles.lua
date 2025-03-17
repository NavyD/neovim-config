---@type LazyPluginSpec[]
return {
  {
    "williamboman/mason.nvim",
    ---@module 'mason'
    ---@type MasonSettings
    opts = {
      ensure_installed = {
        -- "shellcheck", -- lazyvim 已配置
        -- 仅在存在 pwsh 时才会运行 pwsh 启动 LSP 服务
        -- 最好使用 pwsh 7+ https://github.com/PowerShell/PowerShellEditorServices#supported-powershell-versions
        unpack(vim.fn.executable("pwsh") == 1 and { "powershell-editor-services" } or {}),
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      {
        "williamboman/mason.nvim",
        ---@module 'mason'
        ---@type MasonSettings
        -- https://github.com/psacawa/systemd-language-server
        opts = { ensure_installed = { "systemd-language-server" } },
      },
    },
    -- lspconfig lazy 相关配置参考： https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/lang/yaml.lua
    opts = {
      ---@module 'vim.lsp'
      ---@module "lspconfig.configs"
      ---@type lspconfig.options
      ---@diagnostic disable-next-line: missing-fields
      servers = {
        -- https://github.com/psacawa/systemd-language-server#nvim-lspconfig
        -- 内置 systemd_ls 配置 https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/configs/systemd_ls.lua
        ---@type lspconfig.Config
        ---@diagnostic disable-next-line: missing-fields
        systemd_ls = {
          enabled = true,
          -- NOTE: *.service.tmpl 无法加载使用 lsp
          -- 这是由于 systemd-language-server 不支持 tmpl 后缀，使用 `:LspLog`
          -- `raise ve_exc\r\nValueError: 'tmpl' is not a valid UnitType\r\n"`
        },
      },
    },
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
}
