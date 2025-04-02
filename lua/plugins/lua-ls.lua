---@type LazySpec[]
return {
  {
    "LuaCATS/openresty",
    name = "lua-openresty-types",
    lazy = true,
  },
  {
    -- https://github.com/folke/lazydev.nvim
    -- NOTE: 如果当前项目中存在 .luarc.json 文件会导致这些配置无效
    -- [docs: hint how to deal with .luarc.json #64](https://github.com/folke/lazydev.nvim/pull/64)
    "folke/lazydev.nvim",
    ---@module 'lazydev'
    ---@param opts lazydev.Config
    opts = function(_, opts)
      -- [feature: load library on filename #39](https://github.com/folke/lazydev.nvim/issues/39#issuecomment-2203460917)
      ---@type lazydev.Library.spec[]
      local libs = {
        "lua-openresty-types/library",
        -- { path = "luassert-types/library", words = { "assert" } },
        -- { path = "lua-openresty-types/library" },
      }
      vim.list_extend(opts.library, libs)
    end,
  },
}
