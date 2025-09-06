---@type LazyPluginSpec
return {
  "fei6409/log-highlight.nvim",
  -- [configuration](https://github.com/fei6409/log-highlight.nvim#configuration)
  opts = {
    ---@type string|string[]: File extensions. Default: 'log'
    -- extension = "log",

    ---@type string|string[]: File names or full file paths. Default: {}
    -- filename = {
    --   "syslog",
    -- },

    ---@type string|string[]: File name/path glob patterns. Default: {}
    -- pattern = {
    --   -- Use `%` to escape special characters and match them literally.
    --   "%/var%/log%/.*",
    --   "console%-ramoops.*",
    --   "log.*%.txt",
    --   "logcat.*",
    -- },

    ---@type table<string, string|string[]>: Custom keywords to highlight.
    keyword = {
      error = { "ERROR_MSG", "ERR" },
      warning = { "WARN_X", "WARN_Y", "WAR" },
      info = { "INFORMATION", "INF" },
      debug = { "DEB" },
      pass = {},
    },
  },
}
