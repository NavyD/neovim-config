local cmp_source_icons = {
  lsp = "",
  buffer = "",
  snippets = "",
  path = "",
  tags = "",
  cmdline = "󰘳",
  -- FALLBACK
  _fallback = "󰜚",
}
local cmp_comp_name = "source_icon"

---@module 'lazy'
---@type LazyPluginSpec[]
return {
  -- NOTE: 所有需要 BlinkCmpConfigExt.completion_source_icons 的配置都应该在这个 spec
  -- 后再加载，否则会导致某些 spec 的配置无法被加载
  {
    "saghen/blink.cmp",
    optional = true,
    ---@class BlinkCmpConfigExt: blink.cmp.Config
    ---@field completion_source_icons? table<string, string>

    -- 添加自定义的补全窗口组件 source_icon，用于在窗口中显示 blink provider 图标
    ---@param opts BlinkCmpConfigExt
    opts = function(_, opts)
      -- vim.notify(
      --   "opts.completion_source_icons=" .. vim.inspect(opts.completion_source_icons or {}),
      --   vim.log.levels.INFO
      -- )

      if not opts.completion then
        opts.completion = {}
      end
      if not opts.completion.menu then
        opts.completion.menu = {}
      end
      if not opts.completion.menu.draw then
        opts.completion.menu.draw = {}
      end
      if not opts.completion.menu.draw.components then
        opts.completion.menu.draw.components = {}
      end

      if opts.completion.menu.draw.components[cmp_comp_name] then
        vim.notify(
          "Overrode blink.completion.menu.draw.components."
            .. cmp_comp_name
            .. "="
            .. vim.inspect(opts.completion.menu.draw.components[cmp_comp_name]),
          vim.log.levels.WARN
        )
      end
      opts.completion.menu.draw.components[cmp_comp_name] = {
        -- don't truncate source_icon
        ellipsis = false,
        text = function(ctx)
          return cmp_source_icons[ctx.source_name:lower()] or cmp_source_icons._fallback
        end,
        highlight = "BlinkCmpSource",
      }
      cmp_source_icons = vim.tbl_extend("force", cmp_source_icons, opts.completion_source_icons or {})
      -- 移除字段避免 blink 出现非法字段警告
      opts.completion_source_icons = nil
      -- vim.notify("completion_source_icons=" .. vim.inspect(completion_source_icons), vim.log.levels.INFO)
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      completion = {
        menu = {
          draw = {
            -- 表示渲染补全窗口的数据列
            -- https://cmp.saghen.dev/configuration/completion.html#menu-draw
            columns = {
              -- blink 提供的组件
              -- https://cmp.saghen.dev/configuration/completion.html#available-components
              { "label", "label_description", gap = 1 },
              -- { "kind_icon", "kind", gap = 1 },
              { "kind_icon" },
              -- 自定义的 component
              { cmp_comp_name },
            },
          },
        },
      },
    },
  },
}
