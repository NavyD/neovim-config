local is_windows = package.config:sub(1, 1) == "\\"

-- [Get back the output of os.execute in Lua](https://stackoverflow.com/a/326715)
---@return string
local function exec_capture(cmd, raw)
  local f = assert(io.popen(cmd, "r"))
  local s = assert(f:read("*a"))
  f:close()
  if raw then
    return s
  end
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  s = string.gsub(s, "[\n\r]+", " ")
  return s
end

--- Check if a file or directory exists in this path
local function exists(file)
  local ok, err, code = os.rename(file, file)
  if not ok then
    if code == 13 then
      -- Permission denied, but it exists
      return true
    end
  end
  return ok, err
end

-- [nvim: Standard Paths](https://neovim.io/doc/user/starting.html#_standard-paths)
local data_dir
-- if jit.os == "Windows" then
-- Lua的package.config字符串的第一个字符表示当前系统的目录分隔符。
-- Windows使用反斜杠\，而Linux等类Unix系统使用斜杠/
if is_windows then
  data_dir = os.getenv("LOCALAPPDATA") .. "/nvim-data"
else
  data_dir = (os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")) .. "/nvim"
end
local vimruntime_dir = os.getenv("VIMRUNTIME")
if not vimruntime_dir then
  local quote_char = is_windows and [["]] or [[']]
  -- local s = [[nvim --clean --headless --cmd ]] .. quote_char .. [[echo $VIMRUNTIME|q]] .. quote_char
  local cmd = ([[nvim --clean --headless --cmd %secho $VIMRUNTIME|q%s 2>&1]]):format(quote_char, quote_char)
  vimruntime_dir = exec_capture(cmd)
  assert(exists(vimruntime_dir), "Not found vimruntime_dir in `" .. vimruntime_dir .. "`")
end

-- https://luals.github.io/wiki/configuration/#custom-configuration-file
---@type _.lspconfig.settings.lua_ls.Lua
---@diagnostic disable: missing-fields
return {
  runtime = { version = "LuaJIT" },
  format = { enable = false },
  workspace = {
    checkThirdParty = false,
    library = {
      vimruntime_dir,
      -- lazy.nvim 插件目录
      data_dir .. "/lazy",
      -- Depending on the usage, you might want to add additional paths here.
      "${3rd}/luv/library",
      "${3rd}/busted/library",
    },
  },
}
