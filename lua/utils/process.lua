local process = {}

---@param cmd string[] cli args
---@param opts? vim.SystemOpts
---@return vim.SystemCompleted
---@see vim.system
---@diagnostic disable-next-line: unused-function
-- 参考：https://github.com/nvim-neorocks/rocks-git.nvim/blob/ee748e7264fb9d4d7e5e35eadac258a0066d1d0a/lua/rocks-git/git.lua#L29
function process.run_co(cmd, opts)
  local nio_ctrl = require("nio.control")
  local future = nio_ctrl.future()

  ---@type boolean, vim.SystemObj | string
  local ok, so_or_err = pcall(vim.system, cmd, opts, function(sc)
    future.set(sc)
  end)

  if not ok then
    ---@cast so_or_err string
    ---@type vim.SystemCompleted
    local sc = {
      code = 1,
      signal = 0,
      stderr = ("Failed to invoke command `%s`: %s"):format(table.concat(cmd, " "), so_or_err),
    }
    future.set_error(sc)
  end

  return future.wait()
end

return process
