local ulsp = require("utils.lsp")

-- 检查 yamllint 的配置文件是否存在，如果不存在则返回 `-d relaxed` 避免过多警告
-- https://yamllint.readthedocs.io/en/stable/configuration.html#configuration
local function get_yamllint_prepend_args()
  -- 如果存在任意的配置文件
  if
    vim
      .iter({ "$XDG_CONFIG_HOME/yamllint/config", "~/.config/yamllint/config", "$YAMLLINT_CONFIG_FILE" })
      :map(vim.fn.expand)
      :any(function(v)
        return vim.uv.fs_stat(v) ~= nil
      end)
  then
    return
  end

  -- 如果当前或父目录中存在默认配置文件
  local conf_markers = { ".yamllint", ".yamllint.yaml", ".yamllint.yml" }
  local conf_paths = vim.fs.find(conf_markers, {
    upward = true,
    path = vim.uv.cwd(),
    limit = 1,
    stop = vim.uv.os_homedir(),
  })
  if #conf_paths > 0 then
    return
  end

  local json_enc = vim.json.encode
  local gen_data = function()
    local ec = vim.b.editorconfig or {}
    local data = {
      extends = "relaxed",
      rules = {
        ["line-length"] = { max = ec.max_line_length or 120 },
      },
    }
    return json_enc(data)
  end
  -- lint.Linter.args 的类型定义是 (string|fun():string)[]，
  -- 允许 动态参数生成 和 工作目录感知。
  return { "-d", gen_data }
end

---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    opts = ulsp.merge_opts_fn({
      servers = { yamlls = { filetypes = { "yaml", "yaml.jinja", "yaml.gotmpl" } } },
    }),
  },
  {
    "mason-org/mason.nvim",
    ---@type LazyVimMasonOpts
    opts = { ensure_installed = { "yamllint" } },
  },
  {
    "mfussenegger/nvim-lint",
    ---@param opts LazyVimLintOpts
    opts = function(_, opts)
      opts.linters_by_ft.yaml = { "yamllint" }

      opts.linters = opts.linters or {}
      local linter = opts.linters.yamllint or {}
      linter.prepend_args = get_yamllint_prepend_args()
      opts.linters.yamllint = linter
    end,
  },
}
