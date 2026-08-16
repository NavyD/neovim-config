vim.filetype.add({
  extension = {
    j2 = "jinja",
  },
})

---@type hltmpl.Opts
local hltmpl_opts = {
  injections = {
    { node = "content", filetypes = { "jinja" } },
    {
      node = "text",
      -- chezmoitmpl 是其插件配置的如 zsh.chezmoitmpl
      filetypes = { "gotmpl", "chezmoitmpl" },
      language = "gotmpl",
    },
  },
}

---@type string[]
local tmpl_fts = vim
  .iter(hltmpl_opts.injections)
  ---@param inj hltmpl.Injection
  :map(function(inj)
    return inj.language or inj.filetypes
  end)
  :flatten(math.huge)
  :unique()
  :totable()

---@type LazySpec
return {
  {
    dir = vim.fs.joinpath(vim.fn.stdpath("config"), "local_plugins/hltmpl"),
    cond = true,
    ---@type hltmpl.Opts
    opts = hltmpl_opts,
  },
  {
    "neovim/nvim-lspconfig",
    ---@type LazyVimLspOpts
    opts = {
      setup = {
        -- 返回 true 表示不再使用 lazyvim 配置需要主动调用如 vim.lsp.config(),enable()
        ["*"] = function(name, conf_opts)
          -- 传入的 lspconfig 只包括 lazyvim 配置声明的部分，
          -- 需要结合默认配置，否则通常 filetypes 为空
          local fts = conf_opts.filetypes
            or (vim.lsp.config[name] or {}).filetypes
          if not fts or #fts <= 0 then
            return false
          end

          local composite_fts = vim
            .iter(fts)
            :filter(function(ft)
              -- 排除复合类型和模板本身
              return not ft:match("%.") and not vim.list_contains(tmpl_fts, ft)
            end)
            :map(function(ft)
              return vim
                .iter(tmpl_fts)
                :map(function(t)
                  return table.concat({ ft, t }, ".")
                end)
                :totable()
            end)
            :flatten(math.huge)
            :totable()
          conf_opts.filetypes = vim
            .iter({ fts, composite_fts })
            :flatten(math.huge)
            :unique()
            :totable()
          return false
        end,
      },
    },
  },
}
