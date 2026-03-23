---@param msg string
local function log_error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end
---@param msg string
local function log_info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

---@diagnostic disable: unused-function
---@param plugin LazyPlugin
local function build_jieba_co(plugin)
  if vim.fn.executable("curl") ~= 1 then
    log_error("Not found curl for jieba_vim")
    return
  end

  -- jieba so库目录
  local lib_name = "jieba_vim_rs" .. (jit.os == "Windows" and ".dll" or ".so")
  local lib_path = vim.fs.joinpath(plugin.dir, "lua/jieba_vim", lib_name)
  local lib_path_tmp = lib_path .. ".bak"

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
  local url_filename = "jieba_vim_rs-"
  if pat == "x64-linux" then
    url_filename = url_filename .. "x86_64-unknown-linux-gnu-lua51.so"
  elseif pat == "x64-windows" then
    url_filename = url_filename .. "x86_64-pc-windows-msvc-lua51.dll"
  elseif pat == "arm64-linux" then
    url_filename = url_filename .. "aarch64-unknown-linux-gnu-lua51.so"
  else
    log_error("Unsupported arch " .. pat)
    return
  end

  local gh_url_fmt = os.getenv("MASON_GITHUB_DOWNLOAD_URL_TEMPLATE") or "https://github.com/%s/releases/download/%s/%s"
  local gh_url = gh_url_fmt:format("kkew3/jieba.vim", tag_name, url_filename)

  local build_args = { "curl", "-fsSLo", lib_path_tmp, gh_url }
  log_info("Building jieba.vim with args: " .. table.concat(build_args, " "))
  local process = require("utils.process")
  local curl_sc = process.run_co(build_args)
  if curl_sc.code ~= 0 then
    log_error("Failed to run `" .. table.concat(build_args, " ") .. "`: " .. (curl_sc.stderr or ""))
    return
  end

  -- TODO: 移动tmp到Pyd，避免init时无法加载
  -- 在加载前将 tmp 文件移动为实际 pyd 文件，避免加载后无法删除
  log_info("Moving " .. lib_path_tmp .. " to " .. lib_path)
  os.rename(lib_path_tmp, lib_path)
  os.remove(lib_path_tmp)
end

---@module 'lazy.types'
---@type LazyPluginSpec[]
return {
  {
    -- [基于 jieba 的 Vim 按词跳转插件](https://github.com/kkew3/jieba.vim)
    "kkew3/jieba.vim",
    version = "2",
    event = "BufRead",
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
    init = function()
      vim.g.jieba_vim_lazy = 1
      vim.g.jieba_vim_keymap = 1
    end,
  },
}
