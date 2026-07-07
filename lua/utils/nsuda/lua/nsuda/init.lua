-- nsuda — Lua rewrite of suda.vim, OOP Suda class with elevation_cmd_build architecture

local uv = vim.uv

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
      local check_cmd = { "true" }
      local r = vim.system({ exe, "-n", unpack(check_cmd) }, { text = true }):wait()
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
      local ar = vim.system({ exe, "-S", "-p", "", unpack(check_cmd) }, { text = true, stdin = pwd .. "\n" }):wait()
      if ar.code ~= 0 then
        return nil, "sudo authentication failed"
      end
      return { exe, unpack(cmd) }
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

---@param config nsuda.Config
---@return nsuda.Suda
function Suda.new(config)
  ---@type nsuda.Suda
  local o = {
    _config = config,
    _augroup = vim.api.nvim_create_augroup("nsuda", { clear = true }),
    _remembered = {},
    _matcher = nil,
  }
  return setmetatable(o, { __index = Suda })
end

---@param cmd string[]
---@return vim.SystemCompleted?
---@return string? error
function Suda:_elevate(cmd)
  local conf = self._config
  local exe = conf.executable
  local key = conf.elevation_cmd_build_match_fn(exe)
  local f = conf.elevation_cmd_builds[key]
  if not f then
    return nil, "no elevation build for: " .. key
  end
  return f({ exe = exe, cmd = cmd, noninteractive = conf.noninteractive }), nil
end

---@param cmd string[]
---@return string? error
function Suda:exec(cmd)
  local args, err = self:_elevate(cmd)
  if not args then
    return err
  end
  local o = vim.system(args, { text = true }):wait()
  if o.code ~= 0 then
    return "Failed to run cmd=" .. vim.inspect(args) .. " with code=" .. o.code .. " stderr=" .. (o.stderr or "")
  end
  return nil
end

---@param path string
function Suda:read(path)
  path = path:gsub("^(suda://)+", "")
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")

  local stat = uv.fs_stat(path)
  if stat and stat.type == "file" and uv.fs_access(path, "R") then
    return vim.fn.readfile(path, "b")
  end

  local tmp = vim.fn.tempname()
  local exec_err = self:exec(raw_copy_cmd(path, tmp))
  if exec_err then
    pcall(uv.fs_unlink, tmp)
    error("[nsuda] Cannot read " .. path .. ": " .. exec_err)
  end
  local lines = vim.fn.readfile(tmp, "b")
  uv.fs_unlink(tmp)
  return lines
end

function Suda:write(path, lines)
  path = path:gsub("^(suda://)+", "")
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  lines = lines or vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local tmp = vim.fn.tempname()
  vim.fn.writefile(lines, tmp, "b")
  local exec_err = self:exec(raw_copy_cmd(tmp, path))
  uv.fs_unlink(tmp)
  if exec_err then
    error("[nsuda] Cannot write " .. path .. ": " .. exec_err)
  end
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
---@param path string
function Suda:handle_read(buf, path)
  log.info("reading buf=" .. buf .. " for path=" .. path)
  vim.cmd("doautocmd <nomodeline> BufReadPre")
  local ul = vim.o.undolevels
  vim.o.undolevels = -1
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false

  local ok, lines = pcall(self.read, self, path)
  if ok then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, lines)
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].modified = false
    vim.cmd("filetype detect")
  else
    vim.api.nvim_echo({ { "[nsuda] " .. tostring(lines) } }, true, { err = true })
  end

  vim.o.undolevels = ul
  vim.cmd("doautocmd <nomodeline> BufReadPost")
end

function Suda:_do_elevated_write(buf, path, tmp)
  local exec_err = self:exec(raw_copy_cmd(tmp, path))
  if exec_err then
    vim.api.nvim_echo({ { "[nsuda] " .. exec_err } }, true, { err = true })
    return false
  end
  vim.bo[buf].modified = false
  vim.notify("[nsuda] Saved " .. vim.fn.fnamemodify(path, ":~"), vim.log.levels.INFO)
  return true
end

function Suda:handle_protocol_write(buf, path)
  vim.cmd("doautocmd <nomodeline> BufWritePre")
  local tmp = vim.fn.tempname()
  vim.cmd("noautocmd write! " .. vim.fn.fnameescape(tmp))
  self:_do_elevated_write(buf, path, tmp)
  uv.fs_unlink(tmp)
  vim.cmd("doautocmd <nomodeline> BufWritePost")
end

---@param buf integer
---@param path string
function Suda:handle_smart_write(buf, path)
  log.info("handling enter buf=" .. buf .. " name=" .. path)

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

  local tmp = vim.fn.tempname()
  vim.cmd("noautocmd write! " .. vim.fn.fnameescape(tmp))

  if not self:_confirm_elevation(path) then
    uv.fs_unlink(tmp)
    vim.notify("[nsuda] Elevation cancelled", vim.log.levels.WARN)
    vim.cmd("doautocmd <nomodeline> BufWritePost")
    return
  end

  self:_do_elevated_write(buf, path, tmp)
  uv.fs_unlink(tmp)
  vim.cmd("doautocmd <nomodeline> BufWritePost")
end

local function has_protocol(name)
  return name:match("^%w+://") ~= nil
end

---@param buf integer
---@param name string
function Suda:handle_buf_enter(buf, name)
  -- log.info("handling enter buf=" .. buf .. " name=" .. name)
  local buf_key = "_suda_checked"
  if vim.b[buf][buf_key] then
    return
  end
  vim.b[buf][buf_key] = true

  if name == "" or vim.bo[buf].buftype ~= "" then
    return
  end
  if has_protocol(name) then
    return
  end

  local stat = uv.fs_stat(name)
  if stat then
    if stat.type == "directory" then
      return
    end

    if stat.type == "file" then
      if uv.fs_access(name, "W") then
        return
      end

      vim.bo[buf].buftype = "acwrite"
      -- log.info("handling enter buf=" .. buf .. " name=" .. name .. " stat=" .. vim.inspect(stat))

      vim.api.nvim_create_autocmd("BufWriteCmd", {
        group = self._augroup,
        buffer = buf,
        callback = function()
          self:handle_smart_write(buf, vim.fn.expand("<afile>"))
        end,
      })
      return
    end
  else
    local parent = vim.fs.dirname(vim.fn.fnamemodify(name, ":p"))
    while parent ~= vim.fs.dirname(parent) do
      local pstat = uv.fs_stat(parent)
      if pstat and pstat.type == "directory" then
        if uv.fs_access(parent, "W") then
          return
        end

        vim.bo[buf].buftype = "acwrite"
        vim.api.nvim_create_autocmd("BufWriteCmd", {
          group = self._augroup,
          buffer = buf,
          callback = function()
            self:handle_smart_write(buf, vim.fn.expand("<afile>"))
          end,
        })
        return
      end
      parent = vim.fs.dirname(parent)
    end
  end
end

function Suda:register()
  vim.api.nvim_create_autocmd("BufReadCmd", {
    group = self._augroup,
    pattern = "suda://*",
    callback = function(args)
      self:handle_read(args.buf, args.match:gsub("^suda://", ""))
    end,
  })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = self._augroup,
    pattern = "suda://*",
    callback = function(args)
      self:handle_protocol_write(args.buf, args.match:gsub("^suda://", ""))
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
    vim.cmd("edit suda://" .. vim.fn.fnameescape(path))
  end, { nargs = "?", complete = "file" })

  vim.api.nvim_create_user_command("SudaWrite", function(opts)
    local path = opts.args ~= "" and opts.args or vim.fn.expand("%:p")
    vim.cmd("write suda://" .. vim.fn.fnameescape(path))
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
  log.info("suda config=" .. vim.inspect(config))
  Suda.new(config):register()
end

return M
