---@module 'lazy'
---@type LazyPluginSpec[]
return {
  -- session management --
  {
    "folke/persistence.nvim",
    enabled = false,
  },
  {
    -- Simple session management for Neovim with git branching, autoloading and Telescope support
    -- https://github.com/olimorris/persisted.nvim
    "olimorris/persisted.nvim",
    version = "3",
    lazy = false,
    opts = {
      -- 不要自动加载，可以使用 `nvim -c '=require("persisted").load()'` 加载
      autoload = false,
      use_git_branch = true,
      allowed_dirs = {}, -- Table of dirs that the plugin will start and autoload from
      ignored_dirs = {}, -- Table of dirs that are ignored for starting and autoloading
      -- Only save session if a minimum number of buffers are present
      ---@type fun(): boolean
      should_save = function()
        -- Ref: https://github.com/folke/persistence.nvim/blob/166a79a55bfa7a4db3e26fc031b4d92af71d0b51/lua/persistence/init.lua#L46
        local bufs = vim.tbl_filter(function(b)
          if vim.bo[b].buftype ~= "" or vim.tbl_contains({ "gitcommit", "gitrebase", "jj" }, vim.bo[b].filetype) then
            return false
          end
          return vim.api.nvim_buf_get_name(b) ~= ""
        end, vim.api.nvim_list_bufs())
        if #bufs < 1 then
          return false
        end
        return true
      end,
    },
    keys = {
      {
        "<leader>qs",
        function()
          require("persisted").load()
        end,
        desc = "Restore Session",
      },
      {
        "<leader>qS",
        function()
          require("persisted").select()
        end,
        desc = "Select Session",
      },
      {
        "<leader>ql",
        function()
          require("persisted").load({ last = true })
        end,
        desc = "Restore Last Session",
      },
      {
        "<leader>qd",
        function()
          require("persisted").stop()
        end,
        desc = "Don't Save Current Session",
      },
      {
        "<leader>qD",
        function()
          require("persisted").delete_current()
        end,
        desc = "Delete Current Session",
      },
    },
  },
}
