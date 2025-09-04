-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

if vim.g.vscode == 1 then
  -- 参考配置 https://github.com/wenjinnn/.dotfiles/blob/main/xdg/config/nvim/plugin/keymaps.lua
  -- vscode配置：https://github.com/Matt-FTW/dotfiles/blob/main/.config/nvim/lua/plugins/extras/util/vscode.lua
  local keymaps = vim.keymap.set

  ---@class VscodeActionOpts
  ---@field args table?
  ---@field range table?
  ---@field restore_selection boolean?
  ---@field callback function(err: string|nil, ret: any)
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

  local vscode = require("vscode")
  vscode.eval_async("return await vscode.commands.getCommands(true)", {
    ---@diagnostic disable-next-line: unused-local
    callback = function(err, ret)
      -- go to error
      local act_next_err = nil
      local act_prev_err = nil
      -- 检查扩展的命令是否存在
      if vim.list_contains(ret, "go-to-next-error.next.error") then
        -- NOTE: vscode默认的动作不区分err/war/inf
        -- 参考[Go to next error/warning/info #105795](https://github.com/microsoft/vscode/issues/105795)
        act_next_err = "go-to-next-error.next.error"
        act_prev_err = "go-to-next-error.prev.error"
      else
        act_next_err = "editor.action.marker.next"
        act_prev_err = "editor.action.marker.prev"
      end
      keymaps("n", "]e", vsc_actions(act_next_err), { desc = "Go to next error" })
      keymaps("n", "[e", vsc_actions(act_prev_err), { desc = "Go to prev error" })
    end,
  })
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
end
