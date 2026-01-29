local uv = vim.uv
local log_levels = vim.log.levels
local json = vim.json
local env = vim.env

local nio = require("nio")
local nio_ctrl = nio.control
local proc = require("utils.process")

local M = {}

---@class misel.EnvOpts
local default_config = {
  load_env_immediately = false,
  bin_path = "mise",
}

---@class misel.EnvState
---@field prev_env table<string, string>?
---@field prev_cwd string?
---@field loading_cwd? string? 在加载 mise 环境变量时避免重复加载
---@field config misel.EnvOpts

---@class misel.EnvState
local MiseEnvState = {}

---@param opts? misel.EnvOpts
function MiseEnvState.new(opts)
  ---@type misel.EnvState
  local o = {
    config = vim.tbl_deep_extend("force", default_config, opts or {}),
  }
  return setmetatable(o, { __index = MiseEnvState })
end

---@param pathstr string
---@return string
local function deduplicate_pathstr(pathstr)
  local is_windows = uv.os_uname().sysname:match("Windows") ~= nil
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
---@param bin_path string
---@param cwd? string
---@return table<string, string>? env
---@return string? error
local function get_mise_env(bin_path, cwd)
  -- NOTE: 在 windows 上执行
  -- `lua vim.system({'mise', 'env', '--cd', 'C:/Users/navyd/.local/share/chezmoi'}, { text = true }, function(o) print(o.stdout) end)`
  -- 无法获取指定目录的环境变量，只能使用 opts.cwd
  local env_args = { bin_path, "env", "--json", "--quiet" }
  local env_sc = proc.run_co(env_args, { text = true, cwd = cwd })
  if env_sc.code ~= 0 then
    return nil, env_sc.stderr
  end
  local env_str = env_sc.stdout
  if not env_str then
    return nil, "not found stdout for mise env"
  end
  local env_o = json.decode(env_str, { luanil = { object = true, array = true } })
  if not env_o then
    return nil, "Failed to decode json with string: " .. env_str
  end
  return env_o, nil
end

-- Error executing callback:
-- .../AppData/Local/nvim-data/lazy/nvim-nio/lua/nio/tasks.lua:100: Async task failed without callback: The coroutine failed with this message:
-- vim/_options.lua:157: E5560: Vimscript function "setenv" must not be called in a fast event context
---@async
---@param name string
---@return string?
local function getenv(name)
  local future = nio_ctrl.future()
  vim.schedule(function()
    future.set(env[name])
  end)
  return future:wait()
end

---@async
---@param ... string|string[]
---@return table<string, string>
local function getenvs(...)
  local envs = {}
  local names = vim.iter({ ... }):flatten(math.huge):totable()
  for _, name in ipairs(names) do
    envs[name] = getenv(name)
  end
  return envs
end

-- 当执行 mise env 期间更新了指定的环境变量时会多次尝试重新获取直到成功，
-- 可以避免在 mise env 期间环境变量被修改的问题
---@async
---@return table<string, string>?
---@return string?
function MiseEnvState:get_consistent_mise_env()
  local env_names = { "PATH" }
  local prev_envs = getenvs(env_names)

  local count = 0
  local max_count = 3

  while true do
    local mise_env, mise_env_err = get_mise_env(self.config.bin_path, self.loading_cwd)
    if not mise_env then
      return nil, mise_env_err
    end

    local curr_envs = getenvs(env_names)
    if vim.deep_equal(prev_envs, curr_envs) then
      return mise_env, nil
    end

    count = count + 1
    if count >= max_count then
      return nil, ("Failed to get consistent %s env %s times"):format(env_names, max_count)
    end

    local diffstr = vim.diff(vim.inspect(prev_envs), vim.inspect(curr_envs))
    vim.notify(("Re-acquiring mise env due to variable change: %s"):format(diffstr), log_levels.WARN)
    prev_envs = curr_envs
  end
end

---@async
function MiseEnvState:load_mise_env()
  local event = vim.v.event
  -- DirChangedPre=directory, DirChanged=cwd,
  -- local cwd = fs.normalize(event.directory or event.cwd or uv.cwd())
  ---@type string|nil
  ---@diagnostic disable-next-line:undefined-field
  local cwd = event.directory or event.cwd
  if not cwd then
    local uv_cwd, cwd_err_name, cwd_err = uv.cwd()
    if not uv_cwd then
      vim.notify(("Failed to get cwd by %s: %s"):format(cwd_err_name or "", cwd_err or ""), log_levels.ERROR)
      return
    end
    cwd = uv_cwd
  end

  -- 上次切换的目录与此次一样则跳过
  if cwd == self.prev_cwd then
    return
  end
  -- 避免快速切换产生大量进程，这里简单的处理第1个即可
  local loading_cwd = self.loading_cwd
  if loading_cwd then
    if loading_cwd ~= cwd then
      vim.notify(
        ("Ignore the mise env loading directory %s because another directory %s is loading"):format(cwd, loading_cwd),
        log_levels.WARN
      )
    end
    return
  end
  self.loading_cwd = cwd

  vim.notify(("Loading mise env in %s"):format(cwd), log_levels.INFO)
  local mise_env, mise_env_err = self:get_consistent_mise_env()
  if not mise_env then
    vim.notify(mise_env_err or "", log_levels.ERROR)
    return
  end

  -- 去除重复的 paths 避免多次切换目录导致的 PATH 过大的问题
  if mise_env.PATH then
    mise_env.PATH = deduplicate_pathstr(mise_env.PATH)
  end
  -- 配置 mise 环境变量到 vim.env
  for name, value in pairs(mise_env) do
    env[name] = value
  end

  -- 移除之前的环境变量
  if self.prev_env then
    for name, _ in pairs(self.prev_env) do
      -- 如果之前的环境变量不再存在，则从 vim.env 中删除
      -- 可以避免提前移除关键环境变量如 PATH 导致问题，其它存在的变量后续覆盖即可
      if mise_env[name] == nil then
        env[name] = nil
      end
    end
  end

  -- 保存状态
  self.prev_env = mise_env
  self.prev_cwd = cwd
  self.loading_cwd = nil
end

function MiseEnvState:load_env()
  nio.run(function()
    self:load_mise_env()
  end)
end

---@param opts? misel.EnvOpts
function M.setup(opts)
  local me = MiseEnvState.new(opts)
  if me.config.load_env_immediately then
    me:load_env()
  end

  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("mise", { clear = true }),
    callback = function(_)
      if vim.v.event.scope == "global" then
        me:load_env()
      end
    end,
  })
end

return M
