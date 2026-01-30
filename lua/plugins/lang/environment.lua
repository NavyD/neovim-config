---@module 'lazy'
---@type LazySpec
return {
  {
    "misel",
    dir = vim.fs.joinpath(vim.fn.stdpath("config"), "lua/utils"),
    dependencies = { "nvim-neotest/nvim-nio" },
    -- 尽量提前加载环境变量让 lazy 插件也能使用，但这很可能无效，因为启动
    -- `mise env` 也需要不少时间，除非使用环境变量的插件是 lazy 且在 spec
    -- 中不应该直接读取环境变量，而是等到启用插件时读取即要使用函数才有效。
    lazy = false,
    priority = 100,
    cond = vim.fn.executable("mise") == 1,
    ---@type misel.EnvOpts
    opts = { load_env_immediately = vim.env.MISE_SHELL == nil },
  },
  {
    -- The most sophisticated all-in-one toolkit to work with .env files and environment variables in NeoVim
    -- https://github.com/ph1losof/ecolog.nvim
    "ph1losof/ecolog.nvim",
    branch = "v1",
    lazy = false,
    -- 合并 providers 而不是覆盖
    opts_extend = { "providers" },
    ---@class EcologConfigProvider
    ---@field pattern string
    ---@field filetype string | string[]
    ---@field extract_var fun(line:string, col:number):string?
    ---@field get_completion_trigger fun():string

    ---@module 'ecolog'
    ---@class EcologConfigExt: EcologConfig
    ---@field providers? EcologConfigProvider[] | table[]

    ---@type EcologConfigExt
    ---@diagnostic disable: missing-fields
    opts = {
      integrations = {
        blink_cmp = true,
      },
      vim_env = false,
      load_shell = {
        enabled = true,
      },
      -- https://github.com/ph1losof/ecolog.nvim#-custom-providers
      -- 实现参考：
      -- https://github.com/ph1losof/ecolog.nvim/blob/main/lua/ecolog/providers/shell.lua
      providers = {
        {
          -- Pattern to match environment variable access
          -- pattern = "ENV%[['\"]%w['\"]%]",
          pattern = "vim%.env%.[%w_]*",
          -- Filetype(s) this provider supports (string or table)
          filetype = "lua",
          -- Function to extract variable name from the line
          extract_var = function(line, col)
            -- 使用 string.match 正则将变量名解压出来，使用下面的命令测试有效性
            -- `=string.match('vim.env.PATH', 'vim%.env%.(%w+)')`
            -- https://github.com/ferncabrera/nvim/blob/5a151dfe204e8446e864cb48b2e71f918174b60d/lua/plugins/ecolog.lua#L33
            return require("ecolog.utils").extract_env_var(line, col, "vim%.env%.([%w_]*)$")
          end,
          -- Function to return completion trigger pattern
          get_completion_trigger = function()
            return "vim.env."
          end,
        },
      },
    },
    ---@diagnostic enable: missing-fields
    config = function(_, opts)
      -- 注意应该优先配置避免 notification_manager 初始化问题
      require("ecolog").setup(opts or {})

      local nm = require("ecolog.core.notification_manager")
      local orig_warn = nm.warn
      -- 当打开的文件 ft=yaml.ansible 时编辑时会导致 ecolog 不断的提示文件类型的问题，
      -- 但实际是可正常工作的，为了避免频繁的提示，替换原函数并避免输出文件类型的问题。
      -- https://github.com/ph1losof/ecolog.nvim/blob/5e2f01e217b68be5d309382595c608295ad5460c/lua/ecolog/providers/init.lua#L438
      -- 原函数参考：
      -- https://github.com/ph1losof/ecolog.nvim/blob/5e2f01e217b68be5d309382595c608295ad5460c/lua/ecolog/core/notification_manager.lua#L70
      ---@param message string The notification message
      ---@param nm_opts table? Additional options
      nm.warn = function(message, nm_opts)
        if vim.startswith(message, "Filetype contains invalid characters") then
          return
        end
        orig_warn(message, nm_opts)
      end
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    ---@type BlinkCmpConfigExt
    opts = {
      completion_source_icons = { env = "" },
      sources = {
        default = { "ecolog" },
        providers = {
          ecolog = {
            name = "env",
            module = "ecolog.integrations.cmp.blink_cmp",
            async = false,
            score_offset = -1,
          },
        },
      },
    },
  },
}
