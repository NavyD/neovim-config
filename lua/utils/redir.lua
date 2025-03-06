-- NOTE:
-- Thanks @ramainl for inspiration
-- credit: https://gist.github.com/romainl/eae0a260ab9c135390c30cd370c20cd7
-- [Display command output in neovim split window](https://gist.github.com/Leenuus/7a2ea47b88bfe16430b42e4e48122718)

vim.g.DEBUG = false
local log = require("plenary.log").new({
  plugin = "redir",
})

local function redir_open_win(buf, vertical, stderr_p)
  local wn = stderr_p and "redir_sterr_win" or "redir_win"
  if vim.g[wn] == nil then
    local win = vim.api.nvim_open_win(buf, true, {
      vertical = vertical,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = { string.format("%d", win) },
      callback = function()
        vim.g[wn] = nil
      end,
    })
    vim.g[wn] = win
  else
    vim.api.nvim_win_set_buf(vim.g[wn], buf)
  end
end

local function redir_vim_command(cmd, vertical)
  vim.cmd("redir => output")
  vim.cmd("silent " .. cmd)
  vim.cmd("redir END")
  local output = vim.fn.split(vim.g.output, "\n")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, output)

  redir_open_win(buf, vertical)
end

local function redir_shell_command(cmd, lines, vertical, stderr_p)
  local shlex = require("utils.shlex")
  -- 解析 shell 命令为列表
  local shell_args = shlex.split(vim.o.shell) or {}
  assert(#shell_args > 0, "Failed to parse args with shell " .. vim.o.shell)

  local shellcmdflag = vim.o.shellcmdflag
  if shellcmdflag and shellcmdflag ~= "" then
    -- 取出文件名 移除 exe/cmd 后缀
    local shell_exe = vim.fn.fnamemodify(shell_args[1], ":t:r"):lower()
    if shell_exe == "pwsh" or shell_exe == "powershell" then
      -- 找出 `-command` 以 `-c` 开头的所有情况都允许
      local cmd_start_idx, cmd_end_idx = shellcmdflag:find("%s*-[cC]%w*%s*")
      assert(cmd_start_idx ~= nil and cmd_end_idx ~= nil, "Invalid shellcmdflag " .. shellcmdflag)

      -- 解析 `-command` 前的所有命令为列表
      local opts = shlex.split(shellcmdflag:sub(1, cmd_start_idx - 1))
      vim.list_extend(shell_args, opts)
      -- 取 `-command`
      table.insert(shell_args, vim.trim(shellcmdflag:sub(cmd_start_idx, cmd_end_idx)))

      -- 取可能存在的命令
      local cmd_flag_arg = shellcmdflag:sub(cmd_end_idx + 1)
      if cmd_flag_arg ~= "" then
        table.insert(shell_args, cmd_flag_arg)
      end
    else
      vim.list_extend(shell_args, shlex.split(shellcmdflag))
    end
  end
  table.insert(shell_args, cmd)

  local stdin = nil
  if #lines ~= 0 then
    stdin = lines
  end

  local stdout_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("ft", "redir_stdout", { buf = stdout_buf })
  redir_open_win(stdout_buf, vertical)

  local stderr = nil
  if stderr_p then
    local stderr_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("ft", "redir_sterr", { buf = stderr_buf })
    redir_open_win(stderr_buf, vertical, true)
    stderr = function(err, data)
      vim.schedule_wrap(function()
        if data ~= nil then
          local output = vim.fn.split(data, "\n")
          if vim.g.DEBUG then
            log.info("stdout: " .. vim.inspect(output))
          end
          vim.api.nvim_buf_set_lines(stderr_buf, -1, -1, false, output)
        end
      end)()
    end
  end

  if vim.g.DEBUG then
    local report = string.format(
      [[lines: %s
stdin: %s
buf: %d
cmd_str: %s
shell_cmd: %s
]],
      vim.inspect(lines),
      vim.inspect(stdin),
      stdout_buf,
      cmd,
      vim.inspect(shell_args)
    )
    log.info(report)
  end

  vim.notify("Redir command: " .. vim.inspect(shell_args), vim.log.levels.INFO)
  vim.system(shell_args, {
    text = true,
    stdout = function(err, stdout)
      vim.schedule_wrap(function()
        if stdout ~= nil then
          local output = vim.fn.split(stdout, "\n")
          if vim.g.DEBUG then
            log.info("stdout: " .. vim.inspect(output))
          end
          vim.api.nvim_buf_set_lines(stdout_buf, -1, -1, false, output)
        end
      end)()
    end,
    stderr = stderr,
    stdin = stdin,
  }, function(sc)
    if sc.code ~= 0 then
      vim.notify(
        "Failed to redir command `"
          .. vim.inspect(shell_args)
          .. "`:\nreturncode: "
          .. sc.code
          .. "\nstderr:\n"
          .. sc.stderr,
        vim.log.levels.WARN
      )
    end
  end)
end

local function redir(args)
  local cmd = args.args
  local vertical = args.smods.vertical
  local stderr_p = args.bang

  if vim.g.DEBUG then
    log.info(vim.inspect(args))
  end

  if cmd:sub(1, 1) == "!" then
    local range = args.range
    local lines
    if range == 0 then
      lines = {}
    else
      local line1 = args.line1 - 1
      local line2 = args.line2
      line2 = line1 == line2 and line1 + 1 or line2
      lines = vim.api.nvim_buf_get_lines(0, line1, line2, false)
    end

    cmd = cmd:sub(2)
    redir_shell_command(cmd, lines, vertical, stderr_p)
  else
    redir_vim_command(cmd, vertical)
  end
end

vim.api.nvim_create_user_command("Redir", redir, {
  nargs = "+",
  complete = "command",
  range = true,
  bang = true,
})
vim.api.nvim_create_user_command("R", redir, {
  nargs = "+",
  complete = "command",
  range = true,
  bang = true,
})

vim.api.nvim_create_user_command("Mes", function()
  vim.cmd("Redir messages")
end, { bar = true })
vim.api.nvim_create_user_command("M", function()
  vim.cmd("Redir messages")
end, { bar = true })

local function evaler(range)
  return function(bang)
    local line = vim.fn.getline(1)
    local it = string.match(line, "^#!(.*)")

    local cmd = string.format("%sRedir%s !", range, bang and "!" or "")

    if it and it ~= "" then
      vim.cmd(cmd .. it)
    else
      vim.fn.feedkeys(":" .. cmd, "tn")
    end
  end
end

vim.api.nvim_create_user_command("EvalFile", function(args)
  local bang = args.bang
  evaler("%")(bang)
end, { bar = true, bang = true })

vim.api.nvim_create_user_command("EvalLine", function(args)
  local bang = args.bang
  evaler(".")(bang)
end, { bar = true, bang = true })

vim.api.nvim_create_user_command("EvalRange", function(args)
  local bang = args.bang
  evaler("'<,'>")(bang)
end, { bar = true, bang = true, range = true })
