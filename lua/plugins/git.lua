---@type LazyPluginSpec[]
return {
  {
    -- https://github.com/esmuellert/codediff.nvim
    "esmuellert/codediff.nvim",
    version = "2",
    dependencies = { "MunifTanjim/nui.nvim" },
    cmd = "CodeDiff",
    keys = {
      { "<leader>gv", "<cmd>CodeDiff<cr>", desc = "Toggle CodeDiff" },
    },
  },
}
