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
---@async
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

  local gh_url_fmt = os.getenv("MASON_GITHUB_DOWNLOAD_URL_TEMPLATE")
    or "https://github.com/%s/releases/download/%s/%s"
  local gh_url = gh_url_fmt:format("kkew3/jieba.vim", tag_name, url_filename)

  local build_args = {
    "curl",
    -- 断点续传
    "--continue-at",
    "-",
    -- 重试
    "--retry",
    "5",
    "--retry-max-time",
    "10",
    "--retry-connrefused",
    -- 连接超时
    "--connect-timeout",
    "3",
    "--max-time",
    "10",
    "-fsSL",
    "--output",
    lib_path_tmp,
    gh_url,
  }
  log_info("Building jieba.vim with args: " .. table.concat(build_args, " "))
  local process = require("utils.process")
  local curl_sc = process.run_co(build_args)
  if curl_sc.code ~= 0 then
    log_error(
      "Failed to run `"
        .. table.concat(build_args, " ")
        .. "`: "
        .. (curl_sc.stderr or "")
    )
    return
  end

  local auv = require("nio").uv
  if vim.fn.has("win32") == 1 then
    local _, lib_st = auv.fs_stat(lib_path)
    if lib_st then
      -- 在 windows 上先重命名已加载的 dll 避免文件正在使用的错误
      local old_lib_path = lib_path .. ".old"
      log_info("Moving " .. lib_path .. " to " .. old_lib_path)
      local rename_old_err, rename_old_ok =
        auv.fs_rename(lib_path, old_lib_path)
      if not rename_old_ok then
        log_error(
          "Failed to rename "
            .. lib_path
            .. " to "
            .. old_lib_path
            .. " with error: "
            .. (rename_old_err or "")
        )
        -- 重命名忽略错误即可
      end
    end
  end
  log_info("Moving " .. lib_path_tmp .. " to " .. lib_path)
  local rename_err, rename_ok = auv.fs_rename(lib_path_tmp, lib_path)
  if not rename_ok then
    log_error(
      "Failed to rename "
        .. lib_path_tmp
        .. " to "
        .. lib_path
        .. " with error: "
        .. rename_err
    )
    return
  end
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
      -- NOTE: 使用 jieba 重复 `.` 操作要求使用 tpope/vim-repeat 完整支持
      -- https://github.com/tpope/vim-repeat
      { "tpope/vim-repeat" },
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
      -- 是否延迟加载词典直到中文出现
      vim.g.jieba_vim_lazy = 1
      -- 是否自动启用默认键映射
      vim.g.jieba_vim_keymap = 1
    end,
  },
}
