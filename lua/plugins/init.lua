---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    import = "plugins.lang",
  },
  {
    "mason-org/mason.nvim",
    ---@module 'mason'
    ---@type MasonSettings
    -- https://github.com/mason-org/mason.nvim#default-configuration
    opts = {
      github = {
        -- 默认 `https://github.com/%s/releases/download/%s/%s`
        -- 通常可配置为 `https://gh-proxy.com/https://github.com/%s/releases/download/%s/%s`
        download_url_template = vim.env.MASON_GITHUB_DOWNLOAD_URL_TEMPLATE,
      },
    },
  },
}
