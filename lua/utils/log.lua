local fs = vim.fs
local fn = vim.fn

---@class LogMode
---@field name string  日志级别名称，如 "trace", "debug", "info", "warn", "error", "fatal"
---@field hl   string  Neovim 高亮组名，如 "Comment", "ErrorMsg"

---@class LogOptions
---@field _logopts_mark_ boolean?
---@field fmt?        boolean  将第一个消息参数视为格式字符串，后续参数自动 vim.inspect 后填入
---@field lazy?       boolean  消息参数是一个函数，调用它获取字符串
---@field file_only?  boolean  仅输出到文件，不输出到控制台和 quickfix
---@field debug_info_level? integer  覆盖 debug.getinfo 的层级

---@class LogConfig
---@field plugin         string            插件名称，作为日志消息前缀，默认 "log"
---@field use_console    boolean?
---@field highlights     boolean           是否在控制台使用高亮，默认 true
---@field use_file       boolean           是否写入文件，默认 true
---@field outfile        string?           日志文件路径，默认 fn.stdpath("log") .. "/" .. plugin .. ".log"
---@field use_quickfix   boolean           是否写入 quickfix 列表，默认 false
---@field level          string            最低日志级别，必须为 `modes` 中某个条目的 `name`，默认环境变量 DEBUG_LOG 存在时为 "debug"，否则 "info"
---@field modes          LogMode[]         日志级别配置列表，见默认值
---@field float_precision number            浮点数四舍五入精度，默认 0.01
---@field fmt_msg        fun(is_console: boolean, mode_name: string, src_path: string, src_line: integer, msg: string): string  消息格式化函数
---@field debug_info_level     integer

-- 默认配置
---@type LogConfig
local default_config = {
  plugin = "log",
  use_console = true,
  highlights = true,
  use_file = false,
  outfile = nil,
  use_quickfix = false,
  level = (function()
    local env = fn.getenv("DEBUG_LOG")
    return (env ~= vim.NIL and env ~= "" and env ~= "0") and "debug" or "info"
  end)(),
  modes = {
    { name = "trace", hl = "Comment" },
    { name = "debug", hl = "Comment" },
    { name = "info", hl = "None" },
    { name = "warn", hl = "WarningMsg" },
    { name = "error", hl = "ErrorMsg" },
    { name = "fatal", hl = "ErrorMsg" },
  },
  float_precision = 0.01,
  fmt_msg = function(is_console, mode_name, src_path, src_line, msg)
    local nameupper = mode_name:upper()
    local lineinfo = src_path .. ":" .. src_line
    local ms = math.floor(vim.uv.hrtime() / 1000000) % 1000
    local time_str = string.format("%s.%03d", os.date("%Y-%m-%d %H:%M:%S", os.time()), ms)
    if is_console then
      return string.format("[%3s][%s] %s: %s", nameupper, time_str, lineinfo, msg)
    else
      return string.format("[%3s][%s] %s: %s\n", nameupper, time_str, lineinfo, msg)
    end
  end,
  --- log.log 通常被 log.info 调用，所有需要从 3 开始以获取 log.info 外的调用者信息
  debug_info_level = 3,
}

---四舍五入到指定精度
---@param x number
---@param increment? number
---@return number
local function round(x, increment)
  if x == 0 then
    return x
  end
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
end

---@param v any
---@param opts {float_precision: number?, lazy: boolean?}?
---@return string
local function make_string(v, opts)
  opts = opts or {}
  local ty = type(v)
  if ty == "number" and opts.float_precision then
    v = tostring(round(v, opts.float_precision))
  elseif ty == "table" then
    v = vim.inspect(v)
  elseif ty == "function" and opts.lazy then
    local ok, res = pcall(v)
    if not ok then
      res = "lazy call error: " .. vim.inspect(res)
    end
    -- 递归
    if type(res) ~= "string" then
      return make_string(res, opts)
    end
    v = res
  else
    v = tostring(v)
  end
  return v
end

---@param config LogConfig
---@param opts LogOptions
---@param msg_args any[]
---@return string
local function make_msg_args2string(config, opts, msg_args)
  if #msg_args == 0 then
    return ""
  end
  local str_args = vim
    .iter(msg_args)
    :map(function(arg)
      return make_string(arg, { float_precision = config.float_precision, lazy = opts.lazy })
    end)
    :totable()
  if not opts.fmt then
    return table.concat(str_args, " ")
  end
  return string.format(unpack(str_args))
end

---写入日志到文件
---@param text string
---@param outfile string
local function write_to_file(text, outfile)
  local dir = fs.dirname(outfile)
  if fn.isdirectory(dir) == 0 then
    fs.mkdir(dir, { parents = true })
  end
  local fp = io.open(outfile, "a")
  if fp then
    fp:write(text)
    fp:close()
  end
end

---输出到控制台（使用 nvim_echo）
---@param level_config LogMode
---@param console_string string
---@param config LogConfig
local function output_to_console(config, level_config, console_string)
  local lines = vim.split(console_string, "\n", { plain = true })
  local chunks = {}
  for i, line in ipairs(lines) do
    if i > 1 then
      table.insert(chunks, { "\n", "None" })
    end
    local prefix = (i == 1) and string.format("[%s]", config.plugin) or ""
    table.insert(chunks, {
      prefix .. line,
      (config.highlights and level_config.hl ~= "None" and level_config.hl) or "None",
    })
  end
  vim.api.nvim_echo(chunks, true, {})
end

---判断一个表是否为选项表（包含控制键）
---@param t LogOptions|any
---@return boolean
local function is_options_table(t)
  return type(t) == "table" and t._logopts_mark_ ~= nil
end

---@param config LogConfig
local function gen_log_fn(config)
  ---计算最终的输出文件路径
  ---@type string
  local outfile = config.outfile or fs.joinpath(fn.stdpath("log"), config.plugin .. ".log")

  ---级别名称到数字（越高越严重）
  local levels = {}
  ---级别名称到 LogMode 的映射
  local modes_by_name = {}
  for i, v in ipairs(config.modes) do
    levels[v.name] = i
    modes_by_name[v.name] = v
  end

  -- 核心日志方法
  ---@param level string 日志级别名称
  ---@param ... any|LogOptions 消息参数，最后一个若为选项表则作为控制选项
  return function(level, ...)
    local level_num = levels[level]
    local level_config = modes_by_name[level]
    if not level_num or not level_config then
      -- 未知级别，丢弃（或可打印警告）
      return
    end
    local min_level = levels[config.level]
    if not min_level or level_num < min_level then
      return
    end

    -- 解析选项表和消息参数
    ---@type LogOptions | {}
    local opts = {}
    local msg_args = { ... }
    if is_options_table(msg_args[#msg_args]) then
      opts = table.remove(msg_args)
    end
    -- 构造消息字符串
    local msg = make_msg_args2string(config, opts, msg_args)

    -- 获取调用源信息。默认 2 表示获取调用当前外的函数信息
    local info_level = opts.debug_info_level or config.debug_info_level
    local info = debug.getinfo(info_level, "Sl")
    local src_path = info and info.source:sub(2) or "?"
    local src_line = info and info.currentline or 0

    -- 输出到控制台（除非 file_only）
    if config.use_console and not opts.file_only then
      local console_string = config.fmt_msg(true, level_config.name, src_path, src_line, msg)
      vim.schedule(function()
        output_to_console(config, level_config, console_string)
      end)
    end

    -- 输出到文件
    if config.use_file then
      local file_string = config.fmt_msg(false, level_config.name, src_path, src_line, msg)
      write_to_file(file_string, outfile)
    end

    -- 输出到 quickfix（除非 file_only）
    if config.use_quickfix and not opts.file_only then
      local nameupper = level_config.name:upper()
      local formatted_msg = string.format("[%s] %s", nameupper, msg)
      fn.setqflist({}, "a", {
        items = {
          {
            filename = src_path,
            lnum = src_line,
            col = 1,
            text = formatted_msg,
          },
        },
      })
    end
  end
end
--- 获取调用者的 Lua 模块名（即 require 时使用的名称）
---@param level integer 调用栈层级，默认为 2（调用当前函数的上一层）
---@return string|nil module_name 如 "telescope.builtin"，找不到则返回 nil
local function get_caller_package_name(level)
  level = level or 2

  -- 1. 获取调用者的文件路径
  local info = debug.getinfo(level, "S")
  if not info or not info.source then
    return nil
  end

  -- info.source 通常以 '@' 开头
  local file_path = info.source:sub(2)
  if file_path == "" or fn.isabsolutepath(file_path) ~= 1 then
    return
  end

  -- 2. 遍历 runtimepath (rtp) 查找 lua/ 目录
  local rtp_paths = vim.opt.rtp:get()
  if type(rtp_paths) ~= "table" then
    return nil
  end
  for _, rtp in ipairs(rtp_paths) do
    -- 标准 Neovim 模块位于 rtp 下的 lua/ 目录
    -- 截取 lua/ 之后的相对路径
    local rel_path = fs.relpath(fs.joinpath(rtp, "lua"), file_path)
    if rel_path then
      local mod_name = rel_path
      -- 特殊处理 init.lua：将 /init 替换为父级命名空间
      -- 例如 lua/telescope/init.lua -> "telescope"
      if fs.basename(rel_path) == "init.lua" then
        mod_name = fs.dirname(rel_path)
      else
        -- 移除文件扩展名 (.lua)
        local ext = fs.ext(rel_path)
        if ext ~= "" then
          mod_name = mod_name:sub(1, -#ext - 2)
        end
      end
      -- 将路径分隔符替换为点号（兼容 Windows 反斜杠）
      mod_name = mod_name:gsub("[\\/]", ".")
      return mod_name
    end
  end

  return nil
end

local log = {}

---创建新的日志实例或扩展自身
---@param config? LogConfig 覆盖默认配置
---@param standalone boolean?
log.new = function(config, standalone)
  config = config or {}
  if not config.plugin then
    local pkg_name = get_caller_package_name(3)
    if pkg_name then
      config.plugin = pkg_name
    end
  end
  config = vim.tbl_deep_extend("force", default_config, config or {})

  ---日志实例（将动态添加方法）
  ---@class log.Logger
  local logger = {}
  if standalone then
    logger = log
  end

  logger.log = gen_log_fn(config)

  -- 便捷方法：六个基本级别
  ---@vararg any | LogOptions?
  logger.trace = function(...)
    logger.log("trace", ...)
  end
  ---@vararg any | LogOptions?
  logger.debug = function(...)
    logger.log("debug", ...)
  end
  ---@vararg any | LogOptions?
  logger.info = function(...)
    -- local args = { ... } -- 收集所有可变参数
    -- args[#args + 1] = { _mark_ = true, debug_info_level = 3 } -- 追加 table
    -- obj.log("info", unpack(args))
    logger.log("info", ...)
  end
  ---@vararg any | LogOptions?
  logger.warn = function(...)
    logger.log("warn", ...)
  end
  ---@vararg any | LogOptions?
  logger.error = function(...)
    logger.log("error", ...)
  end
  ---@vararg any | LogOptions?
  logger.fatal = function(...)
    logger.log("fatal", ...)
  end

  return logger
end

log.new(default_config, true)

return log
