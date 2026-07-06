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

return {}
