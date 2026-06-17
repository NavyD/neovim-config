---@type LazySpec
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
  {
    "lewis6991/gitsigns.nvim",
    optional = true,
    -- NOTE: 下面的是排查过程结论，以作警示
    --
    -- 当 gitsigns current_line_blame 启用时，在进入一个新的 buffer 时会检查当前仓库对应文件 blobs，由于 lazy.nvim
    -- 使用部分克隆会导致 blobs 不完全，触发 gitsigns 使用 git fetch 更新 blobs，如果网络不稳定会出现 UI
    -- 完全卡顿的现象，GIT_NO_LAZY_FETCH 环境变量是 Git 内部用于防止部分克隆（partial clone）
    -- 中按需获取导致递归或安全风险的环境变量。设为 1 时，会阻止某些自动触发的不安全获取行为快速失败。
    --
    -- 但不能简单的配置 `vim.env.GIT_NO_LAZY_FETCH = "1"` 会导致 lazy.nvim install/update 等其它 git 进程部分克隆失败，
    -- 且由于 gitsigns.nvim/plugin/gitsigns.lua 的存在导致 lazy.nvim 在 config() 前会加载运行 setup()，导致常规的
    -- config() 中代理无效，且 lazy.nvim 懒加载的插件不会触发 `SourcePre` 这个事件，也无法在其中代理。
    --
    -- 下面使用 hack require package 的方式提前加载一个代理对象 `gitsigns.system`，这个代理对象会在 gitsigns.system
    -- 被 require 加载时使用，首次使用会移除proxy并请求真实的 gitsigns.system，重新缓存初始化过的 proxy 为
    -- gitsigns.system
    --
    -- 最后我发现这是 lensline 的问题，下面的 nvim 启动的子进程命令导致 UI 阻塞，但排查 gitsigns 项目中
    -- 一直无法找到这种命令：
    -- `/usr/bin/git -C /home/navyd/.local/share/nvim/lazy/gitsigns.nvim blame --line-porcelain -L 1,362 /home/navyd/.local/share/nvim/lazy/gitsigns.nvim/lua/gitsigns/highlight.lua`
    -- 下面的是其子进程 fetch -> git-remote-https 网络阻塞导致
    -- `/usr/lib/git-core/git -c fetch.negotiationAlgorithm=noop fetch origin --no-tags --no-write-fetch-head --recurse-submodules=no --filter=blob:none --stdin`
    -- 还以为是由于 vim.system 的 bug 导致 GIT_NO_LAZY_FETCH 无法传递给子进程，但正常的
    -- vim.env.GIT_NO_LAZY_FETCH 又可以正常工作。许久之后我问 deepseek 这个命令是在哪里启动的，才知道是 lensline
    -- 的问题。
    --
    -- init = function()
    --   local loaded_pkgs = package.loaded
    --   local pkg_name = "gitsigns.system"
    --
    --   local proxy = {}
    --   local target = nil
    --   --- @param cmd string[]
    --   --- @param opts vim.SystemOpts
    --   --- @param on_exit fun(obj: vim.SystemCompleted)
    --   function proxy.system(cmd, opts, on_exit)
    --     -- 首次使用
    --     if not target then
    --       -- 移除未使用过的 proxy
    --       loaded_pkgs[pkg_name] = nil
    --
    --       -- 由于 package.loaded 已移除了proxy，所以可以请求真实的 gitsigns.system
    --       ---@module 'gitsigns.system'
    --       local gs_sys = require(pkg_name)
    --       target = gs_sys.system
    --
    --       -- 重新缓存为初始化过的 proxy
    --       loaded_pkgs[pkg_name] = proxy
    --     end
    --
    --     opts = opts or {}
    --     opts.env = vim.tbl_extend(
    --       "force",
    --       opts.env or {},
    --       { GIT_NO_LAZY_FETCH = "1", GIT_HTTP_LOW_SPEED_LIMIT = "8192", GIT_HTTP_LOW_SPEED_TIME = "2" }
    --     )
    --     vim.notify("Running gitsigns cmd: " .. vim.inspect(cmd) .. " opts: " .. vim.inspect(opts), vim.log.levels.INFO)
    --     return target(cmd, opts, on_exit)
    --   end
    --   -- 提前加载 gitsigns.system 代理对象
    --   loaded_pkgs[pkg_name] = proxy
    -- end,
    -- https://github.com/lewis6991/gitsigns.nvim#installation--usage
    ---@module 'gitsigns'
    ---@type Gitsigns.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      -- Toggle with `:Gitsigns toggle_current_line_blame`
      -- 启用git blame line
      current_line_blame = true,
      current_line_blame_opts = {
        delay = 300,
      },
    },
  },
}
