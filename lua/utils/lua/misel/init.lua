local M = {}

---@class misel.EnvState
M._env_state = {
  ---@type table<string, string>?
  prev_env = nil,
  ---@type string?
  prev_cwd = nil,
  ---@type string? 在加载 mise 环境变量时避免重复加载
  loading_cwd = nil,
  ---@class misel.Config
  config = {
    load_env_immediately = false,
    bin_path = "mise",
  },
  path_sep = vim.fn.has("win32") == 1 and ";" or ":",
}
---@class (partial) misel.Opts: misel.Config

---@param pathstr string
---@return string
local function deduplicate_pathstr(pathstr)
  local is_windows = vim.uv.os_uname().sysname:match("Windows") ~= nil
  local path_sep = is_windows and ";" or ":"

  -- -- 2. 将 PATH 字符串拆分为表
  local path_list = vim.split(pathstr, path_sep)
  -- 3. 去重逻辑
  local unique_paths = {}
  local seen = {}

  for _, path in ipairs(path_list) do
    -- 在 Windows 上，路径通常是不区分大小写的，统一转为小写进行比较
    -- 在 Linux/macOS 上，保持原样
    local key = is_windows and string.lower(path) or path

    if not seen[key] then
      seen[key] = true
      table.insert(unique_paths, path)
    end
  end

  -- 4. 重新拼接并赋值给 vim.env.PATH
  return table.concat(unique_paths, path_sep)
end

---@async
---@param cwd? string
---@return table<string, string>? env
---@return string? error
function M.get_mise_env(cwd)
  local proc = require("utils.process")
  local env_args = { M._env_state.config.bin_path, "env", "--json", "--quiet" }
  if cwd then
    vim.list_extend(env_args, { "--cd", cwd })
  end
  local env_sc = proc.run_co(env_args, { text = true })
  if env_sc.code ~= 0 then
    return nil, env_sc.stderr
  end
  local env_str = env_sc.stdout
  if not env_str then
    return nil, "not found stdout for mise env"
  end
  local env_o = vim.json.decode(env_str, { luanil = { object = true, array = true } })
  if not env_o then
    return nil, "Failed to decode json with string: " .. env_str
  end
  return env_o, nil
end

---@async
function M.load_mise_env()
  local cwd = vim.fs.normalize(vim.v.event.directory or vim.fn.getcwd())
  -- 避免快速切换产生大量进程，这里简单的处理第1个即可
  if M._env_state.loading_cwd then
    return
  end
  M._env_state.loading_cwd = cwd

  vim.notify(("Loading mise env from %s"):format(cwd), vim.log.levels.INFO)
  local mise_env, mise_env_err = M.get_mise_env(cwd)
  if not mise_env then
    vim.notify(mise_env_err, vim.log.levels.ERROR)
    return
  end

  -- Error executing callback:
  -- .../AppData/Local/nvim-data/lazy/nvim-nio/lua/nio/tasks.lua:100: Async task failed without callback: The coroutine failed with this message:
  -- vim/_options.lua:157: E5560: Vimscript function "setenv" must not be called in a fast event context
  vim.schedule(function()
    -- 去除重复的 paths 避免多次切换目录导致的 PATH 过大的问题
    if mise_env.PATH then
      mise_env.PATH = deduplicate_pathstr(mise_env.PATH)
    end
    -- 配置 mise 环境变量到 vim.env
    for name, value in pairs(mise_env) do
      vim.env[name] = value
    end

    -- 移除之前的环境变量
    if M._env_state.prev_env then
      for name, value in pairs(M._env_state.prev_env) do
        -- 如果之前的环境变量不再存在，则从 vim.env 中删除
        -- 可以避免提前移除关键环境变量如 PATH 导致问题，其它存在的变量后续覆盖即可
        if mise_env[name] == nil then
          vim.env[name] = nil
        end
      end
    end

    -- 保存状态
    M._env_state.prev_env = mise_env
    M._env_state.prev_cwd = cwd
    M._env_state.loading_cwd = nil
  end)
end

---@param opts? misel.Opts
function M.setup(opts)
  M._env_state.config = vim.tbl_deep_extend("force", M._env_state.config, opts or {})

  local nio = require("nio")
  if M._env_state.config.load_env_immediately then
    nio.run(M.load_mise_env)
  end

  vim.api.nvim_create_autocmd("DirChangedPre", {
    group = vim.api.nvim_create_augroup("mise", { clear = true }),
    callback = function(args)
      if vim.v.event.scope == "global" then
        nio.run(M.load_mise_env)
      end
    end,
  })
end

return M
