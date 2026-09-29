local ignore_unlisted_buftypes = {
  terminal = true,
  -- 通常是插件 UI 如 lsp 弹窗
  nofile = true,
  acwrite = true,
  quickfix = true,
}
vim.api.nvim_create_user_command("BdeleteUnlisted", function()
  ---@type table<integer, boolean|nil>
  local quick_fix_bufs = vim
    .iter(vim.fn.getqflist())
    :filter(function(v)
      return v.bufnr ~= 0
    end)
    :fold({}, function(acc, v)
      acc[v.bufnr] = true
      return acc
    end)

  ---@type vim.fn.getbufinfo.ret.item[]
  local del_bufs = vim
    .iter(vim.fn.getbufinfo())
    :filter(
      ---@param buf vim.fn.getbufinfo.ret.item
      function(buf)
        local bo = vim.bo[buf.bufnr]
        return buf.listed == 0
          and not ignore_unlisted_buftypes[bo.buftype]
          and not quick_fix_bufs[buf.bufnr]
      end
    )
    :totable()
  vim.notify(
    string.format(
      "Closing %d bufs: %s",
      #del_bufs,
      vim.inspect(vim
        .iter(del_bufs)
        :map(
          ---@param v vim.fn.getbufinfo.ret.item
          function(v)
            local bufnr = v.bufnr
            local bo = vim.bo[bufnr]
            return {
              name = v.name,
              bufnr = bufnr,
              buftype = bo.buftype,
              filetype = bo.filetype,
            }
          end
        )
        :totable())
    ),
    vim.log.levels.INFO
  )
  for _, buf in ipairs(del_bufs) do
    local ok, res = pcall(
      vim.api.nvim_buf_delete,
      buf.bufnr,
      { force = false, unload = false }
    )
    if not ok then
      vim.notify(
        string.format(
          "failed to close bufnr=%s by error=%s: %s",
          buf.bufnr,
          (res or ""),
          vim.inspect(buf)
        ),
        vim.log.levels.ERROR
      )
    end
  end
end, {})

---@type LazySpec
return {
  {
    -- [sleuth.vim: Heuristically set buffer options](https://github.com/tpope/vim-sleuth)
    "tpope/vim-sleuth",
  },
}
