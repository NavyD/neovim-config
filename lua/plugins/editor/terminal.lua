-- 非大写避免被持久化
local last_inserted_key = "_snacks_terminal_last_inserted"

---@module 'lazy'
---@type LazySpec
return {
  {
    -- [No worry about nested Nvim in Nvim terminal](https://github.com/brianhuster/unnest.nvim)
    "brianhuster/unnest.nvim",
    lazy = false,
  },
  {
    "folke/snacks.nvim",
    ---@module 'snacks'
    ---@type snacks.Config
    opts = {
      styles = {
        -- NOTE: terminal 的配置会影响 lazygit，必须覆盖
        lazygit = { height = 0.9, on_close = function() end },
        terminal = {
          height = function(_)
            -- 使用大写开头可让 sessionoptions globals 持久化变量值
            return vim.g.Snacks_terminal_height or 0.48
          end,
          on_close = function(w)
            -- 使用百分比的方法可以在窗口关闭打开时与 resized 事件放大/缩小窗口，
            -- 也可以仅使用 height >= 1 的固定大小
            vim.g.Snacks_terminal_height = vim.api.nvim_win_get_height(w.win) / vim.o.lines
          end,
          -- on_win = function(term_win)
          --   -- 保持终端最后的编辑模式在下次进入时保持一致
          --   -- 实现参考：
          --   -- https://github.com/folke/snacks.nvim/blob/ad9ede6a9cddf16cedbd31b8932d6dcdee9b716e/lua/snacks/terminal.lua#L132-L136
          --   -- feature(terminal): opt-in disabling auto-entering insert mode when terminal opens:
          --   -- https://github.com/folke/snacks.nvim/issues/965
          --   -- 如果是首次打开或上次已是插入模式，由于下面的 bug，所以目前仅在
          --   -- buf 未退出时保持上次的 mode，一旦 buf 被重新打开仍然会直接进入插入模式
          --   -- FIXME: 在隐藏打后 normal 模式下会导致光标页面到下面，而还是保持原位置
          --   if vim.g[last_inserted_key] ~= false and vim.api.nvim_get_current_buf() == term_win.buf then
          --     vim.cmd.startinsert()
          --   end
          -- end,
        },
      },
      -- 避免在 terminal 打开时按键会打开另一个新的 terminal 窗口
      -- 如 ansiblels 目录切换时
      ---@type LazyVimSnacksTerminalOptsExt
      terminal = {
        start_insert = true,
        -- 不使用 snacks.terminal 内置的逻辑，自定义逻辑保持最后插入模式
        auto_insert = false,
        hack_on_open = function(term_win, _, _)
          -- 在离开 buf 前更新 last_inserted 为当前的 mode 是否为插入模式
          term_win:on({ "BufLeave", "BufHidden", "BufDelete", "ExitPre" }, function()
            local m = vim.api.nvim_get_mode()
            vim.g[last_inserted_key] = m.mode == "t"
          end, { buf = true })
          -- 在进入 buf 时根据上次是否为插入模式决定是否插入
          term_win:on("BufEnter", function()
            if vim.g[last_inserted_key] then
              vim.cmd.startinsert()
            end
          end, { buf = true })
        end,
      },
    },
  },
}
