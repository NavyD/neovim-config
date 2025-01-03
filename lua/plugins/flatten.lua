---允许在nvim终端中使用pipe打开文件到当前nvim实例如vscode
---参考：https://github.com/willothy/flatten.nvim
---@class LazyPluginSpec
return {
  "willothy/flatten.nvim",
  -- config = true,
  -- or pass configuration with
  opts = {
    nest_if_no_args = true,
  }, -- Ensure that it runs first to minimize delay when opening file from terminal
  lazy = false,
  priority = 11001,
}
