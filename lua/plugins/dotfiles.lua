---@type LazyPluginSpec[]
return {
  {
    "nvim-treesitter/nvim-treesitter",
    ---@module 'nvim-treesitter'
    ---@type TSConfig
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      -- https://github.com/nvim-treesitter/nvim-treesitter#supported-languages
      ensure_installed = {
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
    -- 由于修改部分文件如 chezmoiexternal 保存时会导致自动运行 cz apply 触发更新相关内容。
    -- 禁用以避免这类问题，以后手动运行即可
    enabled = false,
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
