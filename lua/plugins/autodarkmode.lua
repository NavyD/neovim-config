---@type LazyPluginSpec
return {
  -- [auto-dark-mode.nvim](https://github.com/f-person/auto-dark-mode.nvim)
  "f-person/auto-dark-mode.nvim",
  -- 在termux中无效禁止加载
  cond = not (vim.env.PREFIX and string.find(vim.env.PREFIX, "com.termux")),
  opts = {
    update_interval = 1000,
    set_dark_mode = function()
      vim.api.nvim_set_option_value("background", "dark", {})
    end,
    set_light_mode = function()
      vim.api.nvim_set_option_value("background", "light", {})
    end,
  },
}
