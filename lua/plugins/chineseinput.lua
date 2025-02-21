-- 设置venv路径
-- if true then
--   return {}
-- end

---@param msg string
local function log_error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

local data_dir = vim.fn.stdpath("data")
if type(data_dir) == "table" then
  log_error("Found multiple data dirs: " .. vim.inspect(data_dir))
  return
end
local venv_home = vim.fs.joinpath(data_dir, ".venv")
local venv_py_bin = vim.fs.joinpath(venv_home, jit.os == "Windows" and "Scripts/python.exe" or "bin/python3")

---@module 'lazy.types'
---@type LazyPluginSpec[]
return {
  {
    -- [『盘古之白』中文排版自动规范化的 vim 插件](https://github.com/hotoo/pangu.vim)
    "hotoo/pangu.vim",
    lazy = true,
    event = "BufRead",
    vscode = true,
    config = function()
      -- 参考：https://github.com/hotoo/pangu.vim/blob/master/plugin/pangu.vim
      -- 日期两端不留白：我在2017年8月7日生日
      vim.g.pangu_rule_date = 0

      -- NOTE: vscode 中保存时不会触发事件 BufWritePre，使用 bufwritecmd 在`:w`时触发
      -- 不能同时使用，否则会导致在 nvim 中保存 md 文档时一直无法保存
      vim.api.nvim_create_autocmd(vim.g.vscode and "BufWriteCmd" or "BufWritePre", {
        pattern = { "*.md", "*.markdown", "*.txt" },
        callback = function()
          vim.cmd([[ PanguAll ]])
          vim.notify("Formatted with Pangu", vim.log.levels.INFO)
        end,
      })
    end,
    keys = {
      { "<leader>cg", "<CMD>Pangu<CR>", mode = "n", desc = "Format current line with Pangu" },
      -- NOTE: 选中会格式化所有行而不是区域
      { "<leader>cg", ":'<,'>Pangu<CR>", mode = "v", desc = "Format selection lines with Pangu" },
    },
  },
  {
    -- [基于 jieba 的 Vim 按词跳转插件](https://github.com/kkew3/jieba.vim)
    "kkew3/jieba.vim",
    -- version = "*",
    -- 禁止自动升级避免build出问题
    tag = "v1.0.4",
    enabled = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
    -- plenary构建需要
    dependencies = { "nvim-lua/plenary.nvim" },
    -- build = "./build.sh",
    build = jit.os ~= "Windows" and "./build.sh"
      or function(plugin)
        -- NOTE: 在windows上如果已加载了插件再build会由于无法覆盖so,venv相关文件导致失败
        local cargo_bin = vim.fn.exepath("cargo")
        if not cargo_bin then
          log_error("Not found rust cargo to build")
          return
        end
        -- jieba so库目录
        local build_dir = vim.fs.joinpath(plugin.dir, "pythonx")
        local py_binname = vim.fs.basename(venv_py_bin)

        local Job = require("plenary.job")
        local build_args = { cargo_bin, "build", "-r" }
        ---@diagnostic disable: missing-fields
        local build_job = Job:new({
          command = build_args[1],
          args = { unpack(build_args, 2) },
          cwd = build_dir,
          enable_recording = true,
          on_start = function()
            vim.notify(
              "Building " .. plugin.name .. " in " .. build_dir .. " with args: " .. table.concat(build_args, " "),
              vim.log.levels.INFO
            )
          end,
          on_exit = function(job, code)
            if code ~= 0 then
              log_error(
                "Failed to build "
                  .. plugin.name
                  .. " with args="
                  .. table.concat(build_args, " ")
                  .. ", code="
                  .. code
                  .. ", stderr: "
                  .. table.concat(job:stderr_result() or {}, "\n")
              )
            end
          end,
        })
        local create_venv_args = { vim.fn.exepath(py_binname) or py_binname, "-m", "venv", venv_home }
        local venv_job = vim.fn.executable(venv_py_bin) == 1 and nil
          or Job:new({
            command = create_venv_args[1],
            args = { unpack(create_venv_args, 2) },
            on_start = function()
              vim.notify(
                "Creating python venv in " .. venv_home .. " with args: " .. table.concat(create_venv_args, " "),
                vim.log.levels.INFO
              )
            end,
            on_exit = function(job, code)
              if code ~= 0 then
                return vim.notify(
                  "Failed to creating venv in "
                    .. venv_home
                    .. " with args="
                    .. table.concat(create_venv_args, " ")
                    .. ", code="
                    .. code
                    .. ", stderr: "
                    .. table.concat(job:stderr_result() or {}, "\n"),
                  vim.log.levels.ERROR
                )
              end
            end,
          })
        local pip_inst_args = { venv_py_bin, "-m", "pip", "install", "pynvim" }
        local pip_job = Job:new({
          command = pip_inst_args[1],
          args = { unpack(pip_inst_args, 2) },
          on_start = function()
            vim.notify("pip installing with args: " .. table.concat(pip_inst_args, " "), vim.log.levels.INFO)
          end,
          on_exit = function(job, code)
            if code ~= 0 then
              return vim.notify(
                "Failed to installing pip packages with args="
                  .. table.concat(create_venv_args, " ")
                  .. ", code="
                  .. code
                  .. ", stderr: "
                  .. table.concat(job:stderr_result() or {}, "\n")
              )
            end
          end,
        })
        if venv_job then
          venv_job:and_then_on_success_wrap(pip_job)
        else
          venv_job = pip_job
        end
        build_job:and_then_on_success_wrap(venv_job)
        build_job:start()
      end,
    vscode = true,
    init = function()
      vim.g.jieba_vim_lazy = 1
      vim.g.jieba_vim_keymap = 1

      if vim.fn.executable(venv_py_bin) ~= 1 then
        vim.notify("Not found python venv bin in " .. venv_py_bin, vim.log.levels.WARN)
      else
        vim.g.python3_host_prog = venv_py_bin
      end
    end,
  },
}
