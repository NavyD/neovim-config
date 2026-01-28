-- feature: emmylua-analyzer support
-- https://github.com/folke/lazydev.nvim/issues/86
---@type LazySpec
return {
  { "LuaCATS/luassert", name = "luassert-types", lazy = true },
  { "LuaCATS/busted", name = "busted-types", lazy = true },
  { "Bilal2453/luvit-meta", name = "luvit-types", lazy = true },
  { "DrKJeff16/wezterm-types", name = "wezterm-types", lazy = true },
  { "LuaCATS/openresty", name = "lua-openresty-types", lazy = true },
  {
    "folke/lazydev.nvim",
    opts_extend = { "library" },
    ---@module 'lazydev'
    ---@type lazydev.Config
    opts = {
      library = {
        { path = "luassert-types/library", words = { "assert" } },
        { path = "luvit-types/library", words = { "vim%.uv" } },
        { path = "busted-types/library", words = { "describe" } },
        { path = "wezterm-types", mods = { "wezterm" } },
        { path = "lua-openresty-types/library", words = { "ngx" } },
        { path = vim.env.VIMRUNTIME, words = { "vim" } },
      },
    },
  },
  {
    "folke/lazydev.nvim",
    optional = true,
    -- 由于 emmylua_ls 不包括 luals 内置（过时）addons，需要移除所有包括 `${3rd}` 的路径
    -- https://luals.github.io/wiki/addons/#built-in-addons
    ---@param opts lazydev.Config
    opts = function(_, opts)
      opts.library = vim.tbl_filter(function(e)
        local ty = type(e)
        local path = ""
        if ty == "string" then
          path = e
        elseif ty == "table" then
          path = e.path
        end
        return not string.find(path, "${3rd}", 1, true)
      end, opts.library or {})
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ---@type PluginLspOpts
    opts = {
      servers = {
        -- 禁用 lua ls
        lua_ls = { enabled = false },
        emmylua_ls = {
          settings = {
            -- https://github.com/god464/nvim/blob/f35ab158d7295e89e389244e474806e05fdb5687/.emmyrc.json
            -- https://github.com/EmmyLuaLs/emmylua-analyzer-rust/blob/main/docs/config/emmyrc_json_EN.md
            Lua = {
              runtime = { version = "LuaJIT" },
              -- 如果加载所有的 lua 文件会导致内存过大通常能达到 1GB 以上，
              -- 使用 lazydev.nvim 懒加载可以避免这个问题
              workspace = {
                -- library = { "$VIMRUNTIME", "${3rd}/luv/library", vim.fs.joinpath(vim.fn.stdpath("data"), "lazy") },
                -- library = { vim.fs.joinpath(vim.fn.stdpath("data"), "lazy") },
              },
              strict = { typeCall = true, arrayIndex = true },
            },
          },
        },
      },
    },
  },
}
