local git = {}
local process = require("utils.process")

---@diagnostic disable: unused-function

---@param cwd string
---@return string? tag
---@return string? error
function git.get_tag_co(cwd)
  local rev_sc = process.run_co({ "git", "rev-parse", "HEAD" }, { cwd = cwd, text = true })
  if rev_sc.code ~= 0 then
    return nil, rev_sc.stderr
  end
  if not rev_sc.stdout then
    return nil, "Not found any output by git"
  end
  local hash = vim.trim(rev_sc.stdout)

  -- 尝试使用 git tag --points-at $hash 获取 tag 名
  local tag_point_sc = process.run_co({ "git", "tag", "--points-at", hash }, { cwd = cwd, text = true })
  if tag_point_sc.code == 0 and tag_point_sc.stdout then
    local tag_name = vim.trim(tag_point_sc.stdout)
    if tag_name ~= "" then
      return tag_name, nil
    end
  end

  local tag_sc = process.run_co({ "git", "describe", "--exact-match", hash }, { cwd = cwd, text = true })
  if tag_sc.code ~= 0 then
    return nil, tag_sc.stderr
  end
  if not tag_sc.stdout then
    return nil, "Not found any output by git"
  end
  return vim.trim(tag_sc.stdout), nil
end

return git
