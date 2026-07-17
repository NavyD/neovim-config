-- nsuda — Lua rewrite of suda.vim, OOP Suda class with elevation_cmd_build architecture

local uv = vim.uv
local api = vim.api
local fn = vim.fn
local fs = vim.fs

local M = {
  _NAME = "nsuda",
}

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

---@param msg string
---@param hl_group string?
local function echo(msg, hl_group)
  vim.cmd("redraw")
  local chunks = { { string.format("[%s] %s", M._NAME, msg), hl_group or "None" } }
  api.nvim_echo(chunks, true, {})
end

---@class nsuda.BuildElevationCmdCtx
---@field exe string
---@field cmd string[]
---@field noninteractive boolean

---@alias nsuda.BuildElevationCmds table<string, fun(ctx: nsuda.BuildElevationCmdCtx): string[]?,string?>

---@class nsuda.Config
---@field executable string
---@field noninteractive boolean
---@field smart_edit boolean
---@field build_copy_cmd fun(src: string, dst: string): string[] # Platform raw copy command (no elevation prefix)
---@field build_elevation_cmds nsuda.BuildElevationCmds
---@field build_elevation_cmd_match fun(exe: string): string

local is_windows = fn.has("win32") == 1

---@class nsuda.Suda
---@field _config nsuda.Config
local Suda = {}

---@type nsuda.Config
local default_config = {
  executable = "sudo",
  noninteractive = false,
  smart_edit = false,
  build_copy_cmd = function(src, dst)
    if is_windows then
      return { "cmd", "/c", "copy", "/y", src, dst }
    end
    -- `bs=1048576` is equivalent to `bs=1M` for GNU dd or `bs=1m` for BSD dd
    -- Both `bs=1M` and `bs=1m` are non-POSIX
    return { "dd", "if=" .. src, "of=" .. dst, "bs=" .. 1024 * 1024 }
  end,
  build_elevation_cmd_match = function(exe)
    local name = fs.basename(exe)
    if is_windows then
      name = name:lower()
      name = fn.fnamemodify(name, ":r")
    end
    return name
  end,
  -- Default build_elevation_cmds: each is fun(exe, cmd, ctx): string[]?, string?
  build_elevation_cmds = {
    sudo = function(ctx)
      -- sudo.exe for windows
      if is_windows then
        -- 要求 sudo 配置 `sudo config --enable normal` 或在 设置 中指定，否则将会导致 sudo.exe 总是失败
        -- https://learn.microsoft.com/zh-cn/windows/advanced-settings/sudo/#how-to-configure-sudo-for-windows
        -- 指定 `--inline` 与 unix/sudo 行为类似，否则 sudo.exe 进程新建窗口立即返回
        -- code=0 临时文件被删除导致 sudo.exe 在新窗口执行失败
        return { ctx.exe, "--inline", unpack(ctx.cmd) }
      end

      -- sudo for unix
      local cmd_args = { ctx.exe, "-n", unpack(ctx.cmd) }
      if ctx.noninteractive then
        return cmd_args
      end

      local check_cmd_args = { ctx.exe, "-n", "--validate" }
      echo("checking elevation cache with cmd=" .. vim.inspect(check_cmd_args))
      local r = vim.system(check_cmd_args, { text = true }):wait()
      if r.code == 0 then
        return cmd_args
      end

      -- typos: disable-next-line
      local noic = package.loaded["noice"]
      -- 临时禁用 noic 避免 inputsecret 输入后崩溃
      if noic then
        noic.disable()
      end
      local input_ok, pw = pcall(function()
        fn.inputsave()
        local _, pw = pcall(fn.inputsecret, "Sudo Password: ")
        fn.inputrestore()
        return pw
      end)
      if noic then
        noic.enable()
      end
      if not input_ok then
        return nil, pw
      end
      if #pw == 0 then
        return nil, "sudo auth cancelled"
      end

      local cache_args = { ctx.exe, "-S", "-p", "", "--validate" }
      echo("caching elevation with cmd=" .. vim.inspect(cache_args))
      local cache_res = vim.system(cache_args, { text = true, stdin = pw }):wait()
      if cache_res.code ~= 0 then
        return nil, "sudo authentication failed"
      end

      return cmd_args
    end,

    gsudo = function(ctx)
      local check_cmd = { ctx.exe, "status", "--json" }
      echo("checking elevation cache with cmd=" .. vim.inspect(check_cmd))
      local check_res = vim.system(check_cmd, { text = true }):wait()
      if check_res.code ~= 0 then
        return nil, check_res.stderr
      end

      local decode_ok, decode_res = pcall(vim.json.decode, check_res.stdout)
      if not decode_ok then
        return nil, decode_res
      end
      assert(type(decode_res) == "table")
      if not decode_res["CacheAvailable"] then
        local cache_cmd = { ctx.exe, "cache", "on", "-p", uv.os_getpid() }
        echo("caching elevation with cmd=" .. vim.inspect(cache_cmd))
        local cache_res = vim.system(cache_cmd):wait()
        if cache_res.code ~= 0 then
          return nil, "Failed to run cmd=" .. vim.inspect(cache_cmd) .. " with error: " .. (cache_res.stderr or "")
        end
      end

      return { ctx.exe, unpack(ctx.cmd) }, nil
    end,
  },
}

local protocol = { _name = M._NAME .. "://" }

---@param path string
function protocol.join(path)
  path = fn.fnamemodify(fn.expand(path), ":p")
  if protocol.has(path) then
    return path
  end
  return protocol._name .. path
end
---@param protocol_str string
function protocol.get_path(protocol_str)
  local path = protocol_str:gsub("^" .. protocol._name, "")
  path = fn.fnamemodify(fn.expand(path), ":p")
  return path
end
-- 检查字符串是否是一个以 schema 开始的
---@param s string
function protocol.has(s)
  return s:match([[^[a-zA-Z][a-zA-Z0-9+.-]*://]]) ~= nil
end
function protocol.pattern()
  return protocol._name .. "*"
end
---@param buf integer
---@return string path
function protocol.get_buf_path(buf)
  local name = api.nvim_buf_get_name(buf)
  if not name or name == "" then
    return name
  end
  -- 不要检查，在非 suda:// 中使用 SudaWrite 获取的buf path 不包含 suda:// 导致认为非法
  -- if not protocol.is(name) then
  --   return nil, "invalid protocol path=" .. name .. " for buf=" .. buf
  -- end
  return protocol.get_path(name)
end

---@param path string
---@return boolean
local function is_readable(path)
  return uv.fs_access(path, "R") == true
end

-- 检查一个路径是否可写。
-- 由于 windows fs_access 写入判断不可信，使用打开文件 append 检查文件是否可写。
-- 打开不存在的文件也会检查这个文件是否可以写入
---@param path string
---@return boolean
local function is_writable(path)
  local aw = uv.fs_access(path, "W")
  if not is_windows then
    -- 不可写且文件不存在时检查父目录
    return aw or (not uv.fs_stat(path) and uv.fs_access(fs.dirname(path), "W") == true)
  end

  if not aw then
    return false
  end
  local path_exists = uv.fs_stat(path) ~= nil
  local fd = uv.fs_open(path, "a", tonumber("640", 8))
  if not fd then
    return false
  end
  uv.fs_close(fd)
  -- 移除打开不存在的文件时创建的新文件
  if not path_exists then
    uv.fs_unlink(path)
  end
  return true
end

---@param config nsuda.Config
---@return nsuda.Suda
function Suda.new(config)
  ---@type nsuda.Suda
  local o = { _config = config }
  return setmetatable(o, { __index = Suda })
end

---@param cmd string[]
---@return vim.SystemCompleted?
---@return string? error
function Suda:_build_elevation_cmd(cmd)
  local conf = self._config
  local exe = conf.executable
  local key = conf.build_elevation_cmd_match(exe)
  local build_elev_cmd = conf.build_elevation_cmds[key]
  if not build_elev_cmd then
    return nil, "no elevation build key=" .. key .. " for exe=" .. exe
  end
  local ok, elev_cmd, err = pcall(build_elev_cmd, { exe = exe, cmd = cmd, noninteractive = conf.noninteractive })
  ---@cast elev_cmd +string?
  if not ok then
    assert(type(elev_cmd) ~= "table")
    return nil, elev_cmd
  end
  ---@cast elev_cmd -string?
  if not elev_cmd then
    return nil, err
  end
  return elev_cmd, nil
end

---@param src string
---@param dst string
---@return string? error
function Suda:_copy(src, dst)
  local cmd = self._config.build_copy_cmd(src, dst)
  local elev_cmd, err = self:_build_elevation_cmd(cmd)
  if not elev_cmd then
    return err
  end
  echo("Executing elevation copy cmd=" .. vim.inspect(elev_cmd))
  local o = vim.system(elev_cmd, { text = true }):wait()
  if o.code ~= 0 then
    return "Failed to run cmd=" .. vim.inspect(elev_cmd) .. " with code=" .. o.code .. " stderr=" .. (o.stderr or "")
  end
  return nil
end

---@class nsuda.RWOpts
---@field range string
---@field cmdarg string?
---@field cmdbang boolean?

---@param cmd 'read'|'write'
---@param opts nsuda.RWOpts
---@param dst string
---@return string msg
local function vim_exec(cmd, opts, dst)
  opts.cmdarg = opts.cmdarg or vim.v.cmdarg
  if opts.cmdbang == nil then
    opts.cmdbang = vim.v.cmdbang == 1
  end

  -- 0write! ++bin /file
  -- 0read ++bin /file
  local fullcmd = table.concat({
    string.format("%s%s%s", opts.range, cmd, cmd == "read" and "" or (opts.cmdbang and "!" or "")),
    opts.cmdarg,
    fn.fnameescape(dst),
  }, " ")
  echo("executing ex cmd=" .. fullcmd)
  local msg = fn.execute(fullcmd)
  -- local msg = api.nvim_exec2(fullcmd, { output = true }).output
  msg = msg:gsub("^\r?\n", "")
  return msg
end

---@param path string
---@param opts nsuda.RWOpts
---@return string? msg
---@return string? error
function Suda:read(path, opts)
  path = protocol.get_path(path)
  if is_readable(path) then
    return vim_exec("read", opts, path)
  end
  -- 文件不存在
  local stat, _, stat_err_name = uv.fs_stat(path)
  if not stat and stat_err_name == "ENOENT" then
    return nil, nil
  end

  local tmp = fn.tempname()
  local ok, msg, err = pcall(function()
    -- 使用 copy 直接复制到 tempfile 中，相比原 suda 使用
    -- `sudo cat -> write tmp -> read tmp` 的方式避免读取到内存
    local cp_err = self:_copy(path, tmp)
    if cp_err then
      return nil, cp_err
    end
    local msg = vim_exec("read", opts, tmp)
    -- Rewrite message with a correct file name
    msg = msg:gsub(vim.pesc(tmp), fn.fnamemodify(path, ":~"))
    return msg, nil
  end)
  uv.fs_unlink(tmp)

  if not ok then
    return nil, msg
  end
  if err then
    return nil, err
  end
  return msg, nil
end

---@param path string
---@param opts nsuda.RWOpts
---@return string? msg
---@return string? error
function Suda:write(path, opts)
  path = protocol.get_path(path)

  local tmp = fn.tempname()
  local ok, msg, err = pcall(function()
    local msg = vim_exec("write", opts, tmp)

    local path_exists = uv.fs_stat(path) ~= nil
    local cp_err = self:_copy(tmp, path)
    if cp_err then
      return nil, cp_err
    end

    -- Rewrite message with a correct file name
    msg = msg:gsub(vim.pesc(tmp), fn.fnamemodify(path, ":~"))
    if path_exists then
      msg = msg:gsub("%[New%]%s*", "", 1)
    end
    return msg, nil
  end)
  uv.fs_unlink(tmp)

  if not ok then
    return nil, msg
  end
  if err then
    return nil, err
  end
  return msg, nil
end

---@alias AutocmdArgs vim.api.keyset.create_autocmd.callback_args
---@param args AutocmdArgs
function Suda:do_bufenter(args)
  local buf = args.buf
  local buf_key = "_suda_checked"
  if vim.b[buf][buf_key] then
    return
  end
  vim.b[buf][buf_key] = true

  local path = protocol.get_buf_path(buf)
  -- 非文件 buf
  if path == "" or vim.bo[buf].buftype ~= "" or protocol.has(path) then
    return
  end

  local stat = uv.fs_stat(path)
  -- 如果是目录
  if not stat then
    local parent = fs.dirname(path)
    -- 向上找出一个可写的目录，如果其中有目录不可读则表示需要提权
    while parent ~= fs.dirname(parent) do
      if is_writable(parent) then
        return
      end
      local pstat = uv.fs_stat(parent)
      -- 如果是一个不可读的目录
      if pstat and pstat.type == "directory" and not is_readable(path) then
        break
      end
      parent = fs.dirname(parent)
    end
  -- 如果这个文件是可读写的
  elseif stat.type == "directory" or (is_readable(path) and is_writable(path)) then
    return
  end

  local new_buf_name = protocol.join(path)
  -- `edit nsuda:///file` 触发 BufReadCmd，把整个文件内容读入并替换当前缓冲区
  -- vim.cmd("keepalt keepjumps edit " .. fn.fnameescape(new_buf_name))
  api.nvim_cmd({ cmd = "edit", args = { new_buf_name }, mods = { keepalt = true, keepjumps = true } }, {})
  pcall(api.nvim_buf_delete, buf, { force = true })
end

---@param args AutocmdArgs
function Suda:do_bufreadcmd(args)
  local buf = args.buf
  api.nvim_exec_autocmds("BufReadPre", { buffer = buf, modeline = false })

  local ul = vim.o.undolevels
  -- 目的：让 sudo 读取 + 替换 buffer 内容的操作不污染 undo 历史。
  -- 否则用户按 u 会撤销回空 buffer， 没有任何意义。
  vim.o.undolevels = -1

  local ok, msg, err = pcall(function()
    local bufopt = vim.bo[buf]
    bufopt.swapfile = false
    bufopt.undofile = false

    -- 如果 range 是 0，:0read 会把内容放在第 0 行之后（也是开头），
    -- 但在清空缓冲区后第 0 行并不存在，可能引发问题。而 1 明确指代第一行，
    -- Vim 会将内容插入到第一行之前，效果同样是开头
    local msg, err = self:read(args.file, { range = "1" })
    -- 如果 file 不存在 `nil,nil` 则会打开空 buf，避免报错终止，与
    -- edit 打开不存在的文件行为一致
    if not msg and err then
      return nil, err
    end

    -- 静默地删除（丢弃）当前缓冲区的所有行，并保留标记（marks）
    -- `_`: 避免污染用户的 ""（默认寄存器）、"0 或编号寄存器。
    -- lockmarks：执行删除时不更新 '[ 和 '] 等标记的位置，也不影响跳转列表（'' 标记）。
    -- 这样后续的 :read 或其他操作设置的 '[、'] 标记能准确反映新读入内容的位置，
    -- 而不被中间删除干扰。
    vim.cmd("silent lockmarks 0delete _")
    -- 设置 buftype=acwrite 以便写入时触发 BufWriteCmd
    bufopt.buftype = "acwrite"
    bufopt.modified = false

    local ft, ft_state_fn = vim.filetype.match({ buf = buf })
    if ft then
      bufopt.filetype = ft
      if ft_state_fn then
        ft_state_fn(buf)
      end
    end
    return msg, nil
  end)

  vim.o.undolevels = ul

  vim.cmd("redraw")
  if not ok then
    log.error(msg or "empty error")
  end
  if err then
    log.error(err)
  end
  if msg then
    echo(msg)
  end

  api.nvim_exec_autocmds("BufReadPost", { buffer = buf, modeline = false })
end

---@param args AutocmdArgs
function Suda:do_bufwritecmd(args)
  local buf = args.buf
  api.nvim_exec_autocmds("BufWritePre", { buf = buf, modeline = false })

  local msg, err = self:write(args.file, { range = "'[,']" })
  if not msg then
    log.error(err or "empty elevated write error")
  else
    echo(msg)
  end

  local cur_buf_path = fn.expand("%:p")
  -- 只有当写入的是当前 buf 到文件中才修改
  -- 有时可能未通过 suda:// 读取（如普通文件 SudaWrite）
  if cur_buf_path == args.file or protocol.get_path(args.file) == cur_buf_path then
    vim.bo[buf].modified = false
  end

  api.nvim_exec_autocmds("BufWritePost", { buf = buf, modeline = false })
end

---@param args AutocmdArgs
function Suda:do_filereadcmd(args)
  local buf = args.buf
  api.nvim_exec_autocmds("FileReadPre", { buffer = buf, modeline = false })

  local ok, msg, err = pcall(function()
    -- A '[ mark indicates the {range} of the command.
    -- However, the mark becomes 1 even user execute ':0read'.
    -- So check the last command to find if the {range} was 0 or not.
    -- 当用户执行 :0read file（在第 0 行之后，即文件开头插入）时，Vim
    -- 错误地将 '[ 标记设为 1，而不是 0。这意味着如果插件直接使用
    -- '[ 来决定插入位置，:0read 会变成在第 1 行之后插入，
    local range = fn.histget("cmd", -1):match("^0r[ead]*") and "0" or "'["
    return self:read(args.file, { range = range })
  end)
  if not ok then
    log.error(msg or "")
  end
  if err then
    log.error(err)
  end
  if msg then
    echo(msg)
  end

  api.nvim_exec_autocmds("FileReadPost", { buffer = buf, modeline = false })
end

---@param args AutocmdArgs
function Suda:do_filewritecmd(args)
  local buf = args.buf
  api.nvim_exec_autocmds("FileWritePre", { buffer = buf, modeline = false })

  -- '[,']write ...，意思是将当前缓冲区中被最后操作（或整个缓冲区）的文本写入文件
  local msg, err = self:write(args.file, { range = "'[,']" })
  if not msg then
    log.error(err or "")
  else
    echo(msg)
  end

  api.nvim_exec_autocmds("FileWritePost", { buffer = buf, modeline = false })
end

function Suda:setup()
  local pattern = protocol.pattern()
  -- 避免 nsuda:// 类型的文件没有注册 autocmd 被调用时出现 No such autocommand
  -- 原 suda 插件在对应的 autocmd 中均主动运行对应的事件
  api.nvim_create_autocmd({
    "BufReadPre",
    "BufReadPost",
    "FileReadPre",
    "FileReadPost",
    "BufWritePre",
    "BufWritePost",
    "FileWritePre",
    "FileWritePost",
  }, {
    group = api.nvim_create_augroup(M._NAME .. "_internal", { clear = true }),
    pattern = pattern,
    callback = function() end,
  })

  local augroup = api.nvim_create_augroup(M._NAME .. "_edit", { clear = true })
  if self._config.smart_edit then
    api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      pattern = "*",
      nested = true,
      callback = function(args)
        self:do_bufenter(args)
      end,
    })
  end
  ---@param f fun(self: nsuda.Suda, args)
  local cb = function(f)
    return function(args)
      f(self, args)
    end
  end

  api.nvim_create_autocmd("BufReadCmd", {
    group = augroup,
    pattern = pattern,
    callback = cb(self.do_bufreadcmd),
  })
  api.nvim_create_autocmd("BufWriteCmd", {
    group = augroup,
    pattern = pattern,
    callback = cb(self.do_bufwritecmd),
  })
  api.nvim_create_autocmd("FileReadCmd", {
    group = augroup,
    pattern = pattern,
    callback = cb(self.do_filereadcmd),
  })
  api.nvim_create_autocmd("FileWriteCmd", {
    group = augroup,
    pattern = pattern,
    callback = cb(self.do_filewritecmd),
  })

  api.nvim_create_user_command("SudaRead", function(opts)
    local path = opts.args
    if path == "" then
      path = fn.expand("%:p")
      -- 当重新读取当前 buf 文件时删除 buf 再 edit 打开
      vim.cmd("bwipeout")
    end
    vim.cmd.edit(fn.fnameescape(protocol.join(path)))
  end, { nargs = "?", complete = "file" })

  api.nvim_create_user_command("SudaWrite", function(opts)
    local path = opts.args ~= "" and opts.args or fn.expand("%:p")
    -- 在 nsuda:// buf 中运行命令 `SudaWrite` 会出现 nsuda://nsuda:///file 的问题
    vim.cmd.write(fn.fnameescape(protocol.join(path)))
  end, { nargs = "?", complete = "file" })
end

---@param exes string[]
local function find_exepath(exes)
  for _, name in ipairs(exes) do
    local p = fn.exepath(name)
    if p ~= "" then
      return p
    end
  end
  return nil
end

---@param config nsuda.Config
function M.setup(config)
  api.nvim_create_autocmd("VimEnter", {
    group = api.nvim_create_augroup(M._NAME .. "_setup", { clear = true }),
    callback = vim.schedule_wrap(function()
      if not config.executable then
        local exe = find_exepath(is_windows and { "gsudo", "sudo" } or { "sudo" })
        if not exe or exe == "" then
          log.error("Not found any exe")
          return
        end
        config.executable = exe
      end

      config = vim.tbl_deep_extend("keep", config or {}, default_config)
      Suda.new(config):setup()
    end),
  })
end

return M
