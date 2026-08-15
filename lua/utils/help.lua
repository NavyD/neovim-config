local M = {}

local function merge_opts(_, prev_value, value)
  -- 如果新值为 nil，保留旧值（一般不会）
  if value == nil then
    return prev_value
  end

  -- 如果旧值为 nil，直接使用新值
  if prev_value == nil then
    return value
  end

  if type(prev_value) == "table" and type(value) == "table" then
    local prev_islist = vim.islist(prev_value)
    local val_islist = vim.islist(value)

    -- 两个都是列表：合并并去重
    if prev_islist and val_islist then
      return vim.iter({ value, prev_value }):flatten():unique():totable()
    -- 两个都是字典：递归合并（自动进行，但当前函数不递归，需要让深度合并继续处理）
    elseif not prev_islist and not val_islist then
      return vim.tbl_deep_extend(merge_opts, prev_value, value)
    end
  end
  -- 否则返回新值
  return value
end

-- 返回一个 lazy.nvim opts function，用于合并 lsp 相关配置如
-- `servers.somels.filetypes`。由于 lazy.nvim 的 opt_extend
-- 不支持覆盖，所有需要这个函数合并到配置中
---@param opts LazyVimLspOpts
---@return fun(lazyplugin: any, opts: table): table
---@deprecated
function M.merge_lsp_opts_fn(opts)
  return M.merge_opts(opts)
end

-- 合并 table。可以使用 `merge_opts({} --[[@as SomeType]])` 添加类型
---@generic Opts: table
---@param opts Opts
---@return fun(lazyplugin: any, opts: Opts): Opts
function M.merge_opts(opts)
  return function(_, old_opts)
    return vim.tbl_deep_extend(merge_opts, old_opts, opts)
  end
end

return M
