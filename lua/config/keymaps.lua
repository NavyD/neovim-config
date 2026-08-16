-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

if vim.g.vscode == 1 then
  -- 参考配置 https://github.com/wenjinnn/.dotfiles/blob/main/xdg/config/nvim/plugin/keymaps.lua
  -- vscode配置：https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/util/vscode.lua
  local keymaps = vim.keymap.set
  local notify = require("vscode").notify

  ---@class VscodeActionOpts
  ---@field args table?
  ---@field range table?
  ---@field restore_selection boolean?
  ---@field callback fun(err: string|nil, ret: any)
  ---@class VscodeAction
  ---@field name string
  ---@field opts? VscodeActionOpts
  ---@param ... string|VscodeAction
  -- 参考：https://github.com/vscode-neovim/vscode-neovim#vscodeactionname-opts
  local function vsc_actions(...)
    local args = { ... }
    return function()
      local action = require("vscode").action
      local deepcopy = vim.deepcopy
      for _, o in ipairs(args) do
        local o_ty = type(o)
        if o_ty == "string" then
          action(o)
        elseif o_ty == "table" then
          local opts = o.opts
          opts = opts and deepcopy(opts) or nil
          -- NOTE: 闭包引用table 如果后续更新了opts内容会导致出现`expected function, got number`
          -- 使用deepcopy在每次调用时复制出新的table避免在当前table中更新
          action(o.name, opts)
        else
          vim.notify("invalid type " .. o_ty .. " of vscode args: " .. vim.inspect(o), vim.log.levels.ERROR)
        end
      end
    end
  end

  -- 配置 diagnostic 跳转
  local levels = vim.lsp.log.levels
  ---@param direction 'next'|'prev'
  ---@param level integer
  local function set_diag_keymap(direction, level)
    local level_name = levels[level]:lower()
    local is_info_level = level_name == "info"
    local key = string.format(
      "%s%s",
      direction == "next" and "]" or "[",
      -- 使用首字母 ]d/]w/]e
      is_info_level and "d" or level_name:sub(1, 1)
    )
    -- NOTE: vscode默认的动作不区分err/war/inf 参考
    -- [Go to next error/warning/info #105795](https://github.com/microsoft/vscode/issues/105795)
    local diag_act =
      vsc_actions(string.format("editor.action.marker.%s", direction))
    notify(string.format("setting key %s with level", key, level_name))
    keymaps("n", key, is_info_level and diag_act or vsc_actions({
      -- https://marketplace.visualstudio.com/items?itemName=yy0931.go-to-next-error
      -- 上面的无法区分 warn/error，下面的修复了这个问题
      -- https://marketplace.visualstudio.com/items?itemName=JimmyZJX.go-to-next-problem
      name = string.format("go-to-next-problem.%s", direction),
      opts = {
        args = { severity = { level_name } },
        callback = function(err, _)
          if err then
            notify(
              "Please install the plugin `go-to-next-problem` to avoid "
                .. "falling back to "
                .. level_name
                .. "diagnostic by error: "
                .. vim.inspect(err),
              levels.WARN
            )
            diag_act()
          end
        end,
      },
    }), {
      desc = string.format(
        "Go to %s%s diagnostic",
        direction,
        is_info_level and "" or level_name
      ),
    })
  end
  for _, direction in ipairs({ "next", "prev" }) do
    for _, level in ipairs({ levels.INFO, levels.WARN, levels.ERROR }) do
      set_diag_keymap(direction, level)
    end
  end
  -- Retrieve the list of all available commands. Commands starting with an
  -- underscore are treated as internal commands.
  -- https://code.visualstudio.com/api/references/vscode-api#commands
  -- vscode.eval_async("return await vscode.commands.getCommands(true)", {
  --   ---@param err string?
  --   ---@param ret string[]
  --   callback = function(err, ret)
  --     if err then
  --       vim.notify("error=" .. vim.inspect(err), vim.log.levels.ERROR)
  --       return
  --     end
  --     -- 检查扩展的命令是否存在
  --     -- NOTE: 根据启动方式(local/server)的不同可能会无法找到插件注册的命令，
  --     -- 这是由于VS Code 的懒加载大部分扩展尚未激活
  --     if not vim.list_contains(ret, "go-to-next-problem.next") then
  --       return
  --     end
  --   end,
  -- })

  keymaps(
    "n",
    "]h",
    vsc_actions("workbench.action.editor.nextChange", "workbench.action.compareEditor.nextChange"),
    { desc = "Go to Next Change" }
  )
  keymaps(
    "n",
    "[h",
    vsc_actions("workbench.action.editor.previousChange", "workbench.action.compareEditor.previousChange"),
    { desc = "Go to Prev Change" }
  )

  -- [How do I toggle my explorer in VSCode? #2073](https://github.com/vscode-neovim/vscode-neovim/discussions/2073)
  keymaps(
    "n",
    "<leader>e",
    vsc_actions("workbench.action.toggleSidebarVisibility"),
    { desc = "Toggle workbench explorer" }
  )

  keymaps(
    "n",
    "<leader>fn",
    vsc_actions("workbench.action.files.newUntitledFile"),
    { desc = "File: New Untitled Text File" }
  )
  keymaps("n", "<leader>fp", vsc_actions("workbench.action.openRecent"), { desc = "File: Open Recent" })

  keymaps("n", "<leader>cr", vsc_actions("editor.action.rename"), { desc = "Rename" })
  keymaps("n", "<leader>cf", vsc_actions("editor.action.formatDocument"), { desc = "format" })
  keymaps("n", "<leader>ca", vsc_actions("editor.action.quickFix"), { desc = "code action" })
  keymaps("n", "<leader>cs", vsc_actions("outline.toggleVisibility"), { desc = "toggle outline" })
  keymaps("n", "<leader>co", vsc_actions("editor.action.organizeImports"), { desc = "Organize Imports" })
  keymaps(
    "n",
    "<leader>cm",
    vsc_actions("workbench.action.editor.changeLanguageMode"),
    { desc = "Change Language Mode" }
  )

  keymaps("n", "<leader>sr", vsc_actions("actions.find"), { desc = "Find" })
  keymaps("n", "<leader>sg", vsc_actions("workbench.action.findInFiles"), { desc = "Find in Files" })
  -- 调用vscode命令 <C-S-p>
  keymaps("n", "<leader>sc", vsc_actions("workbench.action.showCommands"), { desc = "Show All Commands" })
  keymaps("n", "<leader>sS", vsc_actions("workbench.action.showAllSymbols"), { desc = "Go to Symbol in Workspace" })

  keymaps("n", "<leader>bd", vsc_actions("workbench.action.closeActiveEditor"), { desc = "Close window" })
  keymaps("n", "<leader>bo", vsc_actions("workbench.action.closeOtherEditors"), { desc = "Close other windows" })
  keymaps(
    "n",
    "<leader>bb",
    vsc_actions("workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup", "list.select"),
    { desc = "Switch to other window" }
  )
  keymaps(
    "n",
    "<leader>br",
    vsc_actions("workbench.action.closeEditorsToTheRight"),
    { desc = "Close Editors to the Right in Group" }
  )
  keymaps(
    "n",
    "<leader>bl",
    vsc_actions("workbench.action.closeEditorsToTheLeft"),
    { desc = "Close Editors to the Left in Group" }
  )
  keymaps(
    "n",
    "<leader>,",
    vsc_actions("workbench.action.quickOpenPreviousRecentlyUsedEditorInGroup"),
    { desc = "Open Previous Recently Used Editor in Group" }
  )

  keymaps("n", "gI", vsc_actions("editor.action.goToImplementation"), { desc = "Go to implementation" })

  keymaps("n", "<leader>uC", vsc_actions("workbench.action.selectTheme"), { desc = "Preferences: Color Theme" })
  keymaps("n", "<leader>uw", vsc_actions("editor.action.toggleWordWrap"), { desc = "View: Toggle Word Wrap" })
  keymaps(
    "n",
    "<leader>ub",
    vsc_actions("workbench.action.toggleLightDarkThemes"),
    { desc = "Preferences: Toggle between Light/Dark Themes" }
  )
  keymaps(
    { "n", "v" },
    "<leader>ghr",
    vsc_actions("git.revertSelectedRanges"),
    { desc = "Git: Revert Selected Ranges" }
  )
  keymaps({ "n", "v" }, "<leader>ge", vsc_actions("workbench.view.scm"), { desc = "View: Show Changes" })

  -- NOTE: 在 vscode 中只能使用 `Alt+Shift+鼠标滚动` 方便水平滚动，没有直接的命令实现 `zH`, `zL`
  -- keymaps("n", "zh", vsc_actions("scrollLeft"), { desc = "scroll left" })
  -- keymaps("n", "zl", vsc_actions("scrollRight"), { desc = "scroll right" })
end
