-- NOTE: require('xxx'), vim.iter():map 等无法补全
local emmyluals_enabled = false

-- feature: emmylua-analyzer support
-- https://github.com/folke/lazydev.nvim/issues/86
---@module 'lazy'
---@type LazySpec
return {
  { "LuaCATS/luassert", name = "luassert-types", lazy = true },
  { "LuaCATS/busted", name = "busted-types", lazy = true },
  { "Bilal2453/luvit-meta", name = "luvit-types", lazy = true },
  { "DrKJeff16/wezterm-types", name = "wezterm-types", lazy = true },
  { "LuaCATS/openresty", name = "lua-openresty-types", lazy = true },
  {
    "folke/lazydev.nvim",
    -- NOTE: 当使用 lazydev emmyluals 时会导致 diagnostics 无法显示，所以禁用，
    -- 使用 .emmyrc.json 配置文件代替
    cond = not emmyluals_enabled,
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
      },
    },
  },
  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@param opts blink.cmp.Config
    opts = function(_, opts)
      if emmyluals_enabled then
        -- 移除 lazydev 的 blink 配置
        -- https://www.lazyvim.org/extras/coding/blink#blinkcmp-2
        opts.sources.providers.lazydev = nil
        opts.sources.per_filetype.lua = nil
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ---@type LazyVimLspOpts
    ---@diagnostic disable-next-line
    opts = {
      servers = {
        -- 禁用 lua ls
        -- FIXME: bug: Workspace libraries not loaded on first buffer with lua_ls 3.17.0
        -- https://github.com/folke/lazydev.nvim/issues/136
        lua_ls = { enabled = not emmyluals_enabled },
        emmylua_ls = {
          enabled = emmyluals_enabled,
          -- settings = {
          --   -- https://github.com/god464/nvim/blob/f35ab158d7295e89e389244e474806e05fdb5687/.emmyrc.json
          --   -- https://github.com/EmmyLuaLs/emmylua-analyzer-rust/blob/main/docs/config/emmyrc_json_EN.md
          --   Lua = {
          --     runtime = { version = "LuaJIT" },
          --     -- 如果加载所有的 lua 文件会导致内存过大通常能达到 1GB 以上，
          --     -- 使用 lazydev.nvim 懒加载可以避免这个问题
          --     workspace = {
          --       library = { "$VIMRUNTIME", "${3rd}/luv/library", vim.fs.joinpath(vim.fn.stdpath("data"), "lazy") },
          --       -- library = { vim.fs.joinpath(vim.fn.stdpath("data"), "lazy"), vim.env.VIMRUNTIME },
          --     },
          --     strict = { typeCall = true, arrayIndex = true },
          --   },
          -- },
        },
      },
    },
  },
}
