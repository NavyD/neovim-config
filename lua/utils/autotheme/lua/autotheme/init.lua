local nio = require("nio")
local auv = nio.uv
local afile = nio.file
-- load nio.file types
if false then
  local _ = require("vim.uv")
end

local json = vim.json

local log = {}
---@param msg string
---@param level vim.log.levels
function log.log(msg, level)
  vim.notify(msg, level)
end

---@param msg string
function log.info(msg)
  log.log(msg, vim.log.levels.INFO)
end

---@param msg string
function log.error(msg)
  log.log(msg, vim.log.levels.ERROR)
end

---@param msg string
function log.warn(msg)
  log.log(msg, vim.log.levels.WARN)
end

--- 使用 vim.defer_fn 实现防抖（利用返回的 timer 取消）
---@generic T
---@param fn fun(...): T  需要防抖执行的函数
---@param delay integer   延迟毫秒数
---@return fun(...): T    防抖后的函数
local function debounced(fn, delay)
  local timer = nil

  return function(...)
    -- 1. 如果有未完成的定时器，取消它
    if timer then
      timer:stop()
      timer = nil
    end

    -- 2. 保存参数
    local args = { ... }

    -- 3. 调度新的延迟回调，并保存返回的 timer 对象
    timer = vim.defer_fn(function()
      timer = nil -- 清空，防止重复 stop（可选）
      fn(unpack(args))
    end, delay)
  end
end

---@param fn fun()
---@param delay integer   延迟毫秒数
local function debounced_co(fn, delay)
  return debounced(function()
    nio.run(fn)
    return nil
  end, delay)
end

local Persisted = {}

---@async
---@param path string
---@return table?
---@return string?
function Persisted.restore(path)
  local file, open_err = afile.open(path, "r")
  if not file then
    return nil, open_err
  end

  local content, r_err = file.read()
  file.close()
  if not content then
    return nil, r_err
  end

  -- 如果文件不存在或为空
  if #content <= 0 then
    return {}, nil
  end

  local jsond_ok, jsond_res = pcall(function()
    return json.decode(content)
  end)
  if not jsond_ok then
    return nil, jsond_res
  end
  assert(type(jsond_res) == "table")
  return jsond_res, nil
end

---@async
---@param path string
---@param o any
---@return string?
function Persisted.save(path, o)
  local file, open_err = afile.open(path, "w+")
  if not file then
    return open_err
  end

  local json_str = json.encode(o)
  -- log.info("Saving object=`" .. json_str .. "` to path " .. path)
  local w_err = file.write(json_str)
  file.close()
  if w_err then
    return w_err
  end
  return nil
end

---@alias BG 'light' | 'dark'

---@class autotheme.BackgroundThemeData
local ThemeData = {
  ---@alias SavedBGTheme string | nil
  ---@type SavedBGTheme
  dark = nil,
  ---@type SavedBGTheme
  light = nil,
  ---@type BG
  background = nil,
}

---@async
---@param path string
---@return autotheme.BackgroundThemeData?
---@return string?
function ThemeData.new(path)
  ---@type autotheme.BackgroundThemeData
  local obj = {}

  local _, stat = auv.fs_stat(path)
  if stat then
    local o, restore_err = Persisted.restore(path)
    if not o then
      return nil, restore_err
    end
    obj = o
  end

  nio.scheduler()
  ---@type autotheme.BackgroundThemeData
  local default = { background = vim.o.background or "dark", dark = {}, light = {} }
  obj = vim.tbl_extend("keep", obj, default)
  return setmetatable(obj, { __index = ThemeData }), nil
end

---@class autotheme.AutoTheme
local AutoTheme = {
  ---@type string
  data_filepath = nil,
  ---@type autotheme.BackgroundThemeData
  themedata = nil,
  ---@type integer
  _save_theme_delay = nil,
  ---@type integer
  _set_theme_delay = nil,
  -- 在 set_theme 中避免 background 循环调用
  ---@type boolean
  _background_lock = nil,
}

---@async
---@param filepath string
---@param augroup integer
---@return autotheme.AutoTheme?
---@return string?
function AutoTheme.new(filepath, augroup)
  local d, d_err = ThemeData.new(filepath)
  if not d then
    return nil, d_err
  end
  local self = setmetatable({
    data_filepath = filepath,
    themedata = d,
    _background_lock = false,
    _save_theme_delay = 500,
    _set_theme_delay = 10,
  }, { __index = AutoTheme })

  -- yield 到主线程以使用 vim.api
  nio.scheduler()

  vim.api.nvim_create_autocmd({ "ColorScheme" }, {
    pattern = "*",
    group = augroup,
    callback = debounced_co(function()
      -- 为了使用 vim.g/vim.o
      nio.scheduler()
      local save_err = self:save_theme(vim.g.colors_name, vim.o.background)
      if save_err then
        log.error("Failed to save theme with error: " .. save_err)
        return
      end
    end, self._save_theme_delay),
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    pattern = "background",
    group = augroup,
    callback = function()
      -- set_theme 会修改 vim.o.background 调用未完成前避免再次调用 set_theme 死循环
      if self._background_lock then
        return
      end
      self:set_theme(vim.v.option_new)
    end,
  })

  return self, nil
end

---@async
---@param name string
---@param background BG
---@return string? error
function AutoTheme:save_theme(name, background)
  if not name or #name <= 0 then
    return "theme name is empty"
  end
  local d = self.themedata
  local last_bg = d.background
  ---@type SavedBGTheme
  local last_bg_theme = d[background]
  if last_bg == background and last_bg_theme == name then
    return
  end

  d.background = background
  d[background] = name
  log.info("Saving " .. background .. " theme " .. name)
  return Persisted.save(self.data_filepath, d)
end

---@param bg BG?
---@return boolean
function AutoTheme:set_theme(bg)
  if not self._set_theme_debounced_fn then
    self._set_theme_debounced_fn = debounced(
      ---@param background BG
      ---@return boolean
      function(background)
        local d = self.themedata
        background = background or d.background
        ---@type SavedBGTheme
        local name = d[background]
        if not name then
          log.warn("Not found hist theme for bg=" .. background)
          return false
        end

        -- 如果主题未修改 或 bg 未修改且在 set_theme 调用中时退出
        if vim.g.colors_name == name or (self._background_lock and vim.o.background ~= background) then
          return false
        end

        self._background_lock = true
        vim.o.background = background

        -- log.info("Setting " .. background .. " theme " .. name)
        local ok, res = pcall(vim.cmd.colorscheme, name)
        self._background_lock = false
        if not ok then
          log.error("Failed to set theme " .. name .. " with error: " .. (res or ""))
          return false
        end
        return true
      end,
      -- 使用 debounced 避免快速切换主题出错其它插件的渲染问题
      self._set_theme_delay
    )
  end
  return self._set_theme_debounced_fn(bg)
end

local M = {}

local _autotheme_fut = nil

function M.setup(_)
  _autotheme_fut = nio.control.future()
  local augroup = vim.api.nvim_create_augroup("MyAutoThemeGroup", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    pattern = "*",
    group = augroup,
    callback = function()
      nio.run(function()
        -- NOTE: 在启动时 yield 到主线程以使用 vim.fn 避免 read file 死循环
        nio.scheduler()
        local filepath = vim.fs.joinpath(vim.fn.stdpath("state"), ".autotheme.json")
        local t, t_err = AutoTheme.new(filepath, augroup)
        if not t then
          log.error("Failed to init autotheme: " .. t_err)
          return
        end
        -- 在启动时优先 set_theme，外部主动的 set_theme 后置生效
        t:set_theme()
        _autotheme_fut.set(t)
      end)
    end,
  })
end

---@param background BG?
function M.set_theme(background)
  nio.run(function()
    if not _autotheme_fut then
      log.error("autotheme is uninit")
      return
    end
    ---@type autotheme.AutoTheme
    local autotheme = _autotheme_fut.wait()
    autotheme:set_theme(background)
  end)
end

return M
