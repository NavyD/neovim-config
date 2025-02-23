local git = {}

---@diagnostic disable: unused-function

---@param cwd string
---@return string? tag
---@return string? error
function git.get_tag_co(cwd)
  local proc = require("nio").process
  local rev_proc, rev_err = proc.run({
    cmd = "git",
    args = { "rev-parse", "HEAD" },
    cwd = cwd,
  })
  if not rev_proc then
    return nil, rev_err
  end
  if rev_proc.result(false) ~= 0 then
    return nil, rev_proc.stderr.read()
  end
  local rev_output, rev_read_err = rev_proc.stdout.read()
  if not rev_output then
    return nil, rev_read_err
  end

  local hash = vim.trim(rev_output)
  local tag_proc, tag_err = proc.run({
    cmd = "git",
    args = { "describe", "--exact-match", hash },
    cwd = cwd,
  })
  if not tag_proc then
    return nil, tag_err
  end
  if tag_proc.result(false) ~= 0 then
    return nil, tag_proc.stderr.read()
  end

  local tag_output, tag_read_err = tag_proc.stdout.read()
  if not tag_output then
    return nil, tag_read_err
  end
  return vim.trim(tag_output), nil
end
return git
