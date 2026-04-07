---@class LazyVimSnacksTerminalOptsExt: snacks.terminal.Opts
---@field hack_on_open? fun(win:snacks.win, cmd?:string|string[], opts?:snacks.terminal.Opts) 在原 open
--- 函数调用后再调用以定制功能

---@module 'lazy'
---@type LazySpec
return {
  "folke/snacks.nvim",
  optional = true,
  ---@param opts snacks.Config
  config = function(_, opts)
    -- HACK: cust terminal open fn
    -- 在调用 open 后再调用定制的 fn
    local t = opts.terminal --[[@as LazyVimSnacksTerminalOptsExt]]
    local hack_on_open = t.hack_on_open
    if hack_on_open then
      local st = require("snacks.terminal")
      local orig_open = st.open
      st.open = function(cmd, t_opts)
        local term_win = orig_open(cmd, t_opts) --[[@as snacks.win]]
        hack_on_open(term_win, cmd, t_opts)
        return term_win
      end
    end

    -- 原始配置
    -- https://github.com/LazyVim/LazyVim/blob/83d90f339defdb109a6ede333865a66ffc7ef6aa/lua/lazyvim/plugins/init.lua#L22
    local notify = vim.notify
    require("snacks").setup(opts)
    -- HACK: restore vim.notify after snacks setup and let noice.nvim take over
    -- this is needed to have early notifications show up in noice history
    if LazyVim.has("noice.nvim") then
      vim.notify = notify
    end
  end,
}
