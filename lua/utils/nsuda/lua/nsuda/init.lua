-- nsuda — Lua rewrite of suda.vim, OOP Suda class with elevation_cmd_build architecture
local is_windows = vim.uv.os_uname().sysname == "Windows_NT"

-- Platform raw copy command (no elevation prefix)
local function raw_copy_cmd(src, dst)
  if is_windows then
    return { "cmd", "/c", "copy", "/y", src, dst }
  end
  return { "dd", "if=" .. src, "of=" .. dst, "bs=1M" }
end

-- Default elevation_cmd_builds: each is fun(exe, cmd, ctx): string[]?, string?
local default_builds = {
  sudo = function(exe, cmd, ctx)
    local r = vim.system({ exe, "-n", "true" }, { text = true }):wait()
    if r.code == 0 then
      return { exe, unpack(cmd) }
    end
    if ctx.noninteractive then
      return nil, "sudo authentication required"
    end
    local pwd = vim.fn.inputsecret(ctx.prompt)
    if #pwd == 0 then
      return nil, "cancelled"
    end
    local ar = vim.system({ exe, "-S", "-p", "", "true" }, { text = true, stdin = pwd .. "\n" }):wait()
    if ar.code ~= 0 then
      return nil, "sudo authentication failed"
    end
    return { exe, unpack(cmd) }
  end,

  gsudo = function(exe, cmd, ctx)
    return { exe, unpack(cmd) }
  end,

  runas = function(exe, cmd, ctx)
    return { exe, "/noprofile", "/user:Administrator", unpack(cmd) }
  end,
}

-- Suda class
local Suda = {}
Suda.__index = Suda

local function defaults()
  return { noninteractive = false, prompt = "Password: ", smart_edit = false }
end

function Suda:new(opts)
  return setmetatable({
    _config = vim.tbl_deep_extend("force", defaults(), opts or {}),
    _group = -1,
    _remembered = {},
    _builds = {},
    _matcher = nil,
  }, Suda)
end

local function default_matcher(exe)
  local name = vim.fs.basename(exe)
  if is_windows then
    name = name:gsub("%.[^.\\/]+$", "")
  end
  return name
end

function Suda:_detect_executable()
  if self._config.executable then
    return self._config.executable
  end
  if is_windows then
    if vim.fn.executable("gsudo") == 1 then return "gsudo" end
    if vim.fn.executable("sudo") == 1 then return "sudo" end
    return "runas"
  end
  return "sudo"
end

function Suda:_resolve_builds()
  self._builds = vim.tbl_deep_extend("force", default_builds, self._config.elevation_cmd_builds or {})
  self._matcher = self._config.elevation_cmd_matcher or default_matcher
end

function Suda:_elevate(cmd)
  local exe = self:_detect_executable()
  local key = self._matcher(exe)
  local f = self._builds[key]
  if not f then
    return nil, "no elevation build for: " .. key
  end
  return f(exe, cmd, {
    noninteractive = self._config.noninteractive,
    prompt = self._config.prompt,
  })
end

function Suda:exec(cmd)
  local args, err = self:_elevate(cmd)
  if not args then
    return { code = -1, stderr = err or "" }
  end
  return vim.system(args, { text = true }):wait()
end

function Suda:read(path)
  path = path:gsub("^(suda://)+", "")
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")

  local stat = vim.uv.fs_stat(path)
  if stat and stat.type == "file" and vim.uv.fs_access(path, "R") then
    return vim.fn.readfile(path, "b")
  end

  local tmp = vim.fn.tempname()
  local r = self:exec(raw_copy_cmd(path, tmp))
  if r.code ~= 0 then
    pcall(vim.uv.fs_unlink, tmp)
    error("[nsuda] Cannot read " .. path .. ": " .. r.stderr)
  end
  local lines = vim.fn.readfile(tmp, "b")
  vim.uv.fs_unlink(tmp)
  return lines
end

function Suda:write(path, lines)
  path = path:gsub("^(suda://)+", "")
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  lines = lines or vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local tmp = vim.fn.tempname()
  vim.fn.writefile(lines, tmp, "b")
  local r = self:exec(raw_copy_cmd(tmp, path))
  vim.uv.fs_unlink(tmp)
  if r.code ~= 0 then
    error("[nsuda] Cannot write " .. path .. ": " .. r.stderr)
  end
end

return {}
