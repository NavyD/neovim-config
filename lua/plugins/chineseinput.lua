-- 设置venv路径
-- if true then
--   return {}
-- end

---@param msg string
local function log_error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end
---@param msg string
local function log_info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

local data_dir = vim.fn.stdpath("data")
if type(data_dir) == "table" then
  log_error("Found multiple data dirs: " .. vim.inspect(data_dir))
  return
end
local venv_home = vim.fs.joinpath(data_dir, ".venv")
local venv_py_bin = vim.fs.joinpath(venv_home, jit.os == "Windows" and "Scripts/python.exe" or "bin/python3")

---@param plugin_dir string
---@return string
---@return string
local function get_pylib_path(plugin_dir)
  local build_dir = vim.fs.joinpath(plugin_dir, "pythonx")
  -- jieba so库目录
  -- https://github.com/kkew3/jieba.vim/issues/10#issuecomment-2565322025
  local pyd_path = vim.fs.joinpath(build_dir, "jieba_vim/jieba_vim_rs") .. (jit.os == "Windows" and ".pyd" or ".so")
  local pyd_path_tmp = pyd_path .. ".bak"
  return pyd_path, pyd_path_tmp
end

---@diagnostic disable: unused-function
---@param plugin LazyPlugin
local function build_jieba_co(plugin)
  local py_binname = vim.fs.basename(venv_py_bin)
  if vim.fn.executable(py_binname) ~= 1 then
    log_error("Not found " .. py_binname)
    return
  end

  -- jieba so库目录
  local pylib_path, pylib_tmp_path = get_pylib_path(plugin.dir)

  local git = require("utils.git")
  local tag_name = plugin.tag
  if not tag_name then
    local tag, tag_err = git.get_tag_co(plugin.dir)
    if not tag then
      log_error("Failed to get tag: " .. (tag_err or ""))
      return
    end
    tag_name = tag
  end

  local pat = string.lower(jit.arch .. "-" .. jit.os)
  local url_filename = "/jieba_vim_rs-"
  if pat == "x64-linux" then
    url_filename = url_filename .. "x86_64-unknown-linux-gnu.so"
  elseif pat == "x64-windows" then
    url_filename = url_filename .. "x86_64-pc-windows-msvc.dll"
  elseif pat == "arm64-linux" then
    url_filename = url_filename .. "aarch64-unknown-linux-gnu.so"
  else
    log_error("Unsupported arch " .. pat)
    return
  end

  local build_args = {
    "curl",
    "-fsSLo",
    pylib_tmp_path,
    "https://github.com/kkew3/jieba.vim/releases/download/" .. tag_name .. url_filename,
  }
  log_info("Building jieba.vim with args: " .. table.concat(build_args, " "))
  local process = require("utils.process")
  local curl_sc = process.run_co(build_args)
  if curl_sc.code ~= 0 then
    log_error("Failed to run `" .. table.concat(build_args, " ") .. "`: " .. (curl_sc.stderr or ""))
    return
  end

  if not vim.uv.fs_stat(venv_py_bin) then
    local create_venv_args = { vim.fn.exepath(py_binname) or py_binname, "-m", "venv", venv_home }
    log_info("Creating python venv in " .. venv_home .. " with args: " .. table.concat(create_venv_args, " "))
    local venv_sc, venv_err = process.run_co(create_venv_args)
    if venv_sc.code ~= 0 then
      log_error("Failed to run `" .. table.concat(create_venv_args, " ") .. "`: " .. (venv_err or ""))
      return
    end

    local pip_inst_args = { venv_py_bin, "-m", "pip", "install", "pynvim" }
    log_info("pip installing with args: " .. table.concat(pip_inst_args, " "))
    local pip_sc, pip_err = process.run_co(pip_inst_args)
    if pip_sc.code ~= 0 then
      log_error("Failed to run `" .. table.concat(pip_inst_args, "") .. ": " .. (pip_err or ""))
      return
    end
  end

  -- TODO: 移动tmp到Pyd，避免init时无法加载
  -- 在加载前将 tmp 文件移动为实际 pyd 文件，避免加载后无法删除
  log_info("Moving " .. pylib_tmp_path .. " to " .. pylib_path)
  os.rename(pylib_tmp_path, pylib_path)
  os.remove(pylib_tmp_path)
end

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
    version = "*",
    -- 禁止自动升级避免build出问题
    -- tag = "v1.0.5",
    event = "BufRead",
    enabled = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
    ---@type LazySpec[]
    dependencies = {
      -- https://github.com/nvim-neotest/nvim-nio
      { "nvim-neotest/nvim-nio" },
    },
    ---@module 'lazy'
    ---@param plugin LazyPlugin
    -- NOTE: 在windows上如果已加载了插件再build会由于无法覆盖so,venv相关文件导致失败
    build = function(plugin)
      require("nio").run(function()
        build_jieba_co(plugin)
      end)
    end,
    vscode = true,
    init = function(plugin)
      if not vim.uv.fs_stat(venv_py_bin) then
        log_error("Not found python venv bin in " .. venv_py_bin .. " for plugin " .. plugin.name)
        return
      end
      vim.g.python3_host_prog = venv_py_bin

      vim.g.jieba_vim_lazy = 1
      vim.g.jieba_vim_keymap = 1
    end,
  },
}
