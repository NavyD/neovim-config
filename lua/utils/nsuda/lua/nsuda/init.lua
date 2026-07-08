-- nsuda — Lua rewrite of suda.vim, OOP Suda class with elevation_cmd_build architecture

local uv = vim.uv
local api = vim.api

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

---@class nsuda.ElevationCmdBuildCtx
---@field exe string
---@field cmd string[]
---@field noninteractive boolean

---@alias nsuda.ElevationCmdBuildFn fun(ctx: nsuda.ElevationCmdBuildCtx): string[]?,string?
---@alias nsuda.ElevationCmdBuilds table<string, nsuda.ElevationCmdBuildFn>

---@class WriteErrorMatchCtx
---@field error string
---@field path string
---@field buf integer

---@class nsuda.Config
---@field executable string
---@field noninteractive boolean
---@field smart_edit boolean
---@field prompt string
---@field elevation_cmd_builds nsuda.ElevationCmdBuilds
---@field elevation_cmd_build_match_fn fun(exe: string): string
---@field write_error_match fun(ctx: WriteErrorMatchCtx): boolean

local is_windows = uv.os_uname().sysname == "Windows_NT"

-- Platform raw copy command (no elevation prefix)
---@param src string
---@param dst string
---@return string[]
local function raw_copy_cmd(src, dst)
  if is_windows then
    return { "cmd", "/c", "copy", "/y", src, dst }
  end
  return { "dd", "if=" .. src, "of=" .. dst, "bs=1M" }
end

---@class nsuda.Suda
---@field _config nsuda.Config
---@field _augroup integer
---@field _remembered table<string, boolean>
local Suda = {}

---@type nsuda.Config
local default_config = {
  executable = "sudo",
  noninteractive = false,
  prompt = "Password: ",
  smart_edit = false,
  write_error_match = function(ctx)
    return ctx.error:match("E212:") and ctx.error:lower():match("permission denied|operation not permitted")
  end,
  elevation_cmd_build_match_fn = function(exe)
    local name = vim.fs.basename(exe)
    if is_windows then
      name = name:lower()
      -- if name ~= "sudo.exe" then
      --   name = vim.fn.fnamemodify(name, ":r")
      -- end
    end
    return name
  end,
  -- Default elevation_cmd_builds: each is fun(exe, cmd, ctx): string[]?, string?
  elevation_cmd_builds = {
    sudo = function(ctx)
      local exe = ctx.exe
      local cmd = ctx.cmd
      local check_cmd_args = { exe, "-n", "--validate" }
      local r = vim.system(check_cmd_args, { text = true }):wait()
      if r.code == 0 then
        return { exe, unpack(cmd) }
      end
      if ctx.noninteractive then
        return nil, "sudo authentication required"
      end
      local pwd = vim.fn.inputsecret("Sudo password: ")
      if #pwd == 0 then
        return nil, "cancelled"
      end
      local cache_args = { exe, "-S", "-p", "", "--validate" }
      local ar = vim.system(cache_args, { text = true, stdin = pwd .. "\n" }):wait()
      if ar.code ~= 0 then
        return nil, "sudo authentication failed"
      end
      return { exe, "-n", unpack(cmd) }
    end,

    ["gsudo.exe"] = function(ctx)
      local check_cmd = { "status", "--json" }
      local r = vim.system({ ctx.exe, unpack(check_cmd) }, { text = true }):wait()
      if r.code ~= 0 then
        return nil, r.stderr
      end
      local decode_ok, decode_res = pcall(vim.json.decode, r.stdout)
      if not decode_ok then
        return nil, decode_res
      end
      assert(type(decode_res) == "table")
      if not decode_res["CacheAvailable"] then
        local ele_cmd = { ctx.exe, "cache", "on", "-p", uv.os_getpid() }
        local ele_res = vim.system(ele_cmd):wait()
        if ele_res.code ~= 0 then
          return nil, "Failed to run cmd=" .. vim.inspect(ele_cmd) .. " with error: " .. (ele_res.stderr or "")
        end
      end
      return { ctx.exe, unpack(ctx.cmd) }, nil
    end,

    ["sudo.exe"] = function(ctx)
      return { ctx.exe, unpack(ctx.cmd) }
    end,
    -- runas = function(ctx)
    --   return { ctx.exe, "/noprofile", "/user:Administrator", unpack(ctx.cmd) }
    -- end,
  },
}

local protocol = { _name = "suda://" }

---@param path string
function protocol.join(path)
  return protocol._name .. path
end
---@param protocol_str string
function protocol.get_path(protocol_str)
  protocol_str = vim.fn.expand(protocol_str)
  local path = protocol_str:gsub("^" .. protocol._name, "")
  path = vim.fn.fnamemodify(path, ":p")
  return path
end
---@param s string
function protocol.is(s)
  return s:match("^" .. protocol._name) ~= nil
end
function protocol.pattern()
  return protocol._name .. "*"
end
---@param buf integer
---@return string? path
---@return string? error
function protocol.get_buf_path(buf)
  local name = api.nvim_buf_get_name(buf)
  if not name or name == "" then
    return nil, "empty buf name"
  end
  if not protocol.is(name) then
    return nil, "invalid protocol path=" .. name .. " for buf=" .. buf
  end
  return protocol.get_path(name), nil
end

---@param config nsuda.Config
---@return nsuda.Suda
function Suda.new(config)
  ---@type nsuda.Suda
  local o = {
    _config = config,
    _augroup = vim.api.nvim_create_augroup("nsuda", { clear = true }),
    _remembered = {},
  }
  return setmetatable(o, { __index = Suda })
end

---@param cmd string[]
---@return vim.SystemCompleted?
---@return string? error
function Suda:_build_elevation_cmd(cmd)
  local conf = self._config
  local exe = conf.executable
  local key = conf.elevation_cmd_build_match_fn(exe)
  local cmd_build_fn = conf.elevation_cmd_builds[key]
  if not cmd_build_fn then
    return nil, "no elevation build for: " .. key
  end
  ---@type boolean, string|string[]?, string?
  local ok, res, res1 = pcall(cmd_build_fn, { exe = exe, cmd = cmd, noninteractive = conf.noninteractive })
  if not ok then
    ---@cast res string
    return nil, res
  end
  ---@cast res string[]?
  if not res then
    return nil, res1
  end
  return res, nil
end

---@param cmd string[]
---@return string? error
function Suda:exec(cmd)
  local elev_cmd, err = self:_build_elevation_cmd(cmd)
  if not elev_cmd then
    return err
  end
  local o = vim.system(elev_cmd, { text = true }):wait()
  if o.code ~= 0 then
    return "Failed to run cmd=" .. vim.inspect(elev_cmd) .. " with code=" .. o.code .. " stderr=" .. (o.stderr or "")
  end
  return nil
end

---@param path string
---@return string[]? data
---@return string? error
function Suda:_read_file(path)
  path = protocol.get_path(path)
  local stat = uv.fs_stat(path)
  if not stat then
    return nil, nil
  end
  if stat and stat.type == "file" and uv.fs_access(path, "R") then
    return vim.fn.readfile(path, "b"), nil
  end

  local tmp = vim.fn.tempname()
  local ok, res, lines = pcall(function()
    local exec_err = self:exec(raw_copy_cmd(path, tmp))
    if exec_err then
      return exec_err, nil
    end
    return nil, vim.fn.readfile(tmp, "b")
  end)
  uv.fs_unlink(tmp)

  if not ok then
    return nil, res
  end
  return lines, res
end

---@param path string
---@return boolean
function Suda:_confirm_elevation(path)
  if self._config.noninteractive then
    return true
  end
  local dir = vim.fs.dirname(path)
  if self._remembered[dir] then
    return true
  end
  local choice = vim.fn.confirm(
    "[nsuda] Elevate and save " .. vim.fn.fnamemodify(path, ":~") .. "?",
    "&Yes\n&Remember\n&No",
    1,
    "Question"
  )
  if choice == 0 or choice == 3 then
    return false
  end
  if choice == 2 then
    self._remembered[dir] = true
  end
  return true
end

---@param buf integer
---@return string? error
function Suda:_load_protocol_buf(buf)
  local path, err = protocol.get_buf_path(buf)
  if not path then
    return err
  end

  local ul = vim.o.undolevels
  -- 目的：让 sudo 读取 + 替换 buffer 内容的操作不污染 undo 历史。
  -- 否则用户按 u 会撤销回空 buffer， 没有任何意义。
  vim.o.undolevels = -1

  local ok, res = pcall(function()
    local bufopt = vim.bo[buf]
    bufopt.swapfile = false
    bufopt.undofile = false

    local lines, read_err = self:_read_file(path)
    if lines then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
    elseif read_err then
      return read_err
    end

    bufopt.buftype = "acwrite"
    bufopt.modified = false
    -- bufopt.readonly = false
    local ft, ft_state_fn = vim.filetype.match({ buf = buf })
    if ft then
      bufopt.filetype = ft
      if ft_state_fn then
        ft_state_fn(buf)
      end
    end
  end)

  vim.o.undolevels = ul

  if not ok or res then
    return res
  end
end

---@param buf integer
function Suda:handle_read(buf)
  api.nvim_exec_autocmds("BufReadPre", { buffer = buf, modeline = false })
  local err = self:_load_protocol_buf(buf)
  if err then
    log.error(err)
  end
  api.nvim_exec_autocmds("BufReadPost", { buffer = buf, modeline = false })
end

---@param buf integer
---@param path string
local function write_buf_to_file(buf, path)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.fn.writefile(lines, path, "b")
end

-- 将 buf 内容写入到临时文件，并将临时文件的内容提权复制到 buf name 对应的真实文件中。
---@param buf integer
---@param conform? boolean
---@return boolean written
---@return string? error
function Suda:_do_elevated_write(buf, conform)
  local tmp = vim.fn.tempname()
  local ok, res = pcall(function()
    local buf_src, buf_src_err = protocol.get_buf_path(buf)
    if not buf_src then
      return buf_src_err or ""
    end

    if conform and not self:_confirm_elevation(buf_src) then
      return false
    end

    write_buf_to_file(buf, tmp)
    return self:exec(raw_copy_cmd(tmp, buf_src))
  end)
  uv.fs_unlink(tmp)
  if not ok then
    ---@cast res string?
    return false, res
  end
  if res then
    return false, res
  end
  -- 取消确认
  if conform and res == false then
    return false, nil
  end

  vim.bo[buf].modified = false
  return true, nil
end

---@param buf integer
function Suda:handle_protocol_write(buf)
  api.nvim_exec_autocmds("BufWritePre", { buf = buf, modeline = false })
  local ok, err = self:_do_elevated_write(buf)
  if not ok then
    error(err or "empty elevated write error")
  end
  api.nvim_exec_autocmds("BufWritePost", { buf = buf, modeline = false })
end

---@param buf integer
---@param path string
function Suda:handle_smart_write(buf, path)
  vim.cmd("doautocmd <nomodeline> BufWritePre")

  local bt = vim.bo[buf].buftype
  vim.bo[buf].buftype = ""
  ---@diagnostic disable-next-line: param-type-mismatch
  local ok, err = pcall(vim.cmd, "noautocmd write")
  vim.bo[buf].buftype = bt

  if ok then
    vim.bo[buf].modified = false
    vim.cmd("doautocmd <nomodeline> BufWritePost")
    return
  end

  local ctx = { error = tostring(err), path = path, buf = buf }
  if not self._config.write_error_match(ctx) then
    vim.api.nvim_echo({ { "[nsuda] " .. tostring(err) } }, true, { err = true })
    vim.cmd("doautocmd <nomodeline> BufWritePost")
    return
  end

  local write_ok, write_err = self:_do_elevated_write(buf, true)
  if not write_ok then
    if write_err then
      error(write_err)
    end
    -- 当交互确认取消时返回 write_err==nil
    log.warn("Cancelled writing elevation to file")
    return
  end

  vim.cmd("doautocmd <nomodeline> BufWritePost")
end

local function has_protocol(name)
  return name:match("^%w+://") ~= nil
end

---@param buf integer
---@param path string
function Suda:handle_buf_enter(buf, path)
  local buf_key = "_suda_checked"
  if vim.b[buf][buf_key] then
    return
  end
  vim.b[buf][buf_key] = true

  path = vim.fn.expand(path)

  if path == "" or vim.bo[buf].buftype ~= "" then
    return
  end
  if has_protocol(path) then
    return
  end

  local stat = uv.fs_stat(path)
  if stat then
    if stat.type == "directory" then
      return
    end

    if stat.type == "file" then
      if uv.fs_access(path, "R") and uv.fs_access(path, "W") then
        return
      end

      local real_path = vim.fn.fnamemodify(path, ":p")
      -- NOTE: 使用 newbuf 代替原buf 不需要修改原buf的状态，如readonly等
      -- 如果不使用 vim.schedule 会导致原buf的messages中仍然存在Permission denied信息
      vim.schedule(function()
        local new_buf = api.nvim_create_buf(true, false)
        api.nvim_set_current_buf(new_buf)
        api.nvim_buf_set_name(new_buf, protocol.join(real_path))
        self:handle_read(new_buf)
        pcall(api.nvim_buf_delete, buf, { force = true })
      end)
      return
    end
  else
    local parent = vim.fs.dirname(vim.fn.fnamemodify(path, ":p"))
    while parent ~= vim.fs.dirname(parent) do
      local pstat = uv.fs_stat(parent)
      if pstat and pstat.type == "directory" then
        if uv.fs_access(parent, "W") then
          return
        end
        vim.schedule(function()
          local new_buf = api.nvim_create_buf(true, false)
          api.nvim_set_current_buf(new_buf)
          api.nvim_buf_set_name(new_buf, protocol.join(path))
          self:_load_protocol_buf(buf)
          api.nvim_buf_delete(buf, { force = true })
        end)
        return
      end
      parent = vim.fs.dirname(parent)
    end
  end
end

function Suda:register()
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = self._augroup,
    pattern = protocol.pattern(),
    callback = function(args)
      self:handle_read(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = self._augroup,
    pattern = protocol.pattern(),
    callback = function(args)
      self:handle_protocol_write(args.buf)
    end,
  })

  if self._config.smart_edit then
    vim.api.nvim_create_autocmd("BufEnter", {
      group = self._augroup,
      pattern = "*",
      nested = true,
      callback = function(args)
        self:handle_buf_enter(args.buf, args.match)
      end,
    })
  end

  vim.api.nvim_create_user_command("SudaRead", function(opts)
    local path = opts.args ~= "" and opts.args or vim.fn.expand("%:p")
    vim.cmd.edit(vim.fn.fnameescape(protocol.join(path)))
  end, { nargs = "?", complete = "file" })

  vim.api.nvim_create_user_command("SudaWrite", function(opts)
    local path = opts.args ~= "" and opts.args or vim.fn.expand("%:p")
    vim.cmd.write(vim.fn.fnameescape(protocol.join(path)))
  end, { nargs = "?", complete = "file" })
end

local M = {}

---@param exes string[]
local function find_exepath(exes)
  for _, name in ipairs(exes) do
    local p = vim.fn.exepath(name)
    if p then
      return p
    end
  end
  return nil
end

---@param config nsuda.Config
function M.setup(config)
  if not config.executable then
    local exe = find_exepath(is_windows and { "gsudo", "sudo" } or { "sudo" })
    if not exe then
      log.error("Not found any exe")
      return
    end
    config.executable = exe
  end

  config = vim.tbl_deep_extend("keep", config or {}, default_config)
  Suda.new(config):register()
end

return M
