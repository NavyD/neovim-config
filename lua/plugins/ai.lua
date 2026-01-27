local function get_ollama_api_key()
  return "_"
end

---@diagnostic disable-next-line
---@return MinuetProviderPresets
local function get_minuet_provider_presets()
  local ollama_base_url = vim.env.MINUET_PROVIDER_OLLAMA_BASE_URL
  if ollama_base_url then
    ollama_base_url = vim.trim(ollama_base_url):gsub("/$", "")
  end
  -- NOTE: 首先声明的顺序将被用于默认的 provider
  ---@class MinuetProviderPresets
  local presets = {
    deepseek = {
      -- NOTE: provider 默认为 provider_options 中的第 1 个键名
      provider = "openai_fim_compatible",
      context_window = 2000,
      -- only send the request every x milliseconds, use 0 to disable throttle.
      throttle = 2000,
      -- debounce the request in x milliseconds, set to 0 to disable debounce
      debounce = 800,
      provider_options = {
        openai_fim_compatible = {
          api_key = "MINUET_PROVIDER_DEEPSEEK_API_KEY",
          name = "deepseek",
          optional = {
            max_tokens = 256,
            top_p = 0.9,
          },
        },
      },
    },
    ollama = {
      provider = "openai_compatible",
      n_completions = 1, -- recommend for local model for resource saving
      -- I recommend beginning with a small context window size and incrementally
      -- expanding it, depending on your local computing power. A context window
      -- of 512, serves as an good starting point to estimate your computing
      -- power. Once you have a reliable estimate of your local computing power,
      -- you should adjust the context window to a larger value.
      -- context_window = 512,
      context_window = 512,
      -- 增加请求时间
      request_timeout = 5,
      provider_options = {
        openai_fim_compatible = {
          -- For Windows users, TERM may not be present in environment variables.
          -- Consider using APPDATA instead.
          api_key = get_ollama_api_key,
          name = "qwen-coder",
          end_point = ollama_base_url and ollama_base_url .. "/v1/completions" or "",
          model = "qwen2.5-coder:1.5b",
          -- only send the request every x milliseconds, use 0 to disable throttle.
          throttle = 800,
          -- debounce the request in x milliseconds, set to 0 to disable debounce
          debounce = 300,
          stream = true,
          optional = {
            max_tokens = 32,
            top_p = 0.9,
          },
        },
        openai_compatible = {
          api_key = get_ollama_api_key,
          name = "sweep-next-edit",
          -- NOTE: sweep-next-edit 不支持 openai_fim_compatible
          -- Can't get qwen3-coder:30b from a local ollama to work
          -- https://github.com/milanglacier/minuet-ai.nvim/issues/125#issuecomment-3724763618
          end_point = ollama_base_url and ollama_base_url .. "/v1/chat/completions" or "",
          model = "sweepai/sweep-next-edit:latest",
          -- only send the request every x milliseconds, use 0 to disable throttle.
          throttle = 800,
          -- debounce the request in x milliseconds, set to 0 to disable debounce
          debounce = 300,
          stream = true,
          optional = {
            max_tokens = 64,
            top_p = 0.9,
          },
        },
      },
    },
  }
  -- 配置默认的 preset._name_.provider = provider_options._key
  -- 但不保证顺序
  for _, config in pairs(presets) do
    if not config.provider then
      -- NOTE: table 无法保持插入顺序
      local opt_name, _ = next(config.provider_options)
      config.provider = opt_name
    end
  end
  return presets
end

-- 从 presets 中获取默认的 preset name
---@param presets? MinuetProviderPresets
local function get_default_preset_name(presets)
  presets = presets or get_minuet_provider_presets()
  -- NOTE: 不保存顺序
  for preset_name, preset in pairs(presets) do
    for _, option in pairs(preset.provider_options) do
      local api_key_ty = type(option.api_key)
      -- 仅当声明 URL 默认或非空 且 api_key 都存在
      if
        option.end_point ~= ""
        and (
          (api_key_ty == "string" and vim.env[option.api_key])
          or (api_key_ty == "function" and type(option.api_key()) == "string")
        )
      then
        return preset_name
      end
    end
  end
  return nil
end

-- 用于快速检查是否被配置被启用
local minuet_preset_inited = false

---@param presets? MinuetProviderPresets
local function minuet_enabled(presets)
  local req_mb_ok, minuet_blink = pcall(require, "minuet.blink")
  if req_mb_ok then
    local e_ok, enabled = pcall(minuet_blink.enabled, minuet_blink)
    if e_ok and enabled and minuet_preset_inited then
      return true
    end
  end
  return get_default_preset_name(presets) ~= nil
end

---@module 'lazy'
---@type LazyPluginSpec[]
return {
  {
    "LazyVim/LazyVim",
    ---@module 'lazyvim'
    ---@type LazyVimOptions
    opts = {
      icons = {
        -- 添加 ai 类型图标到 lazyvim.icons.kinds 中，可以被 lazyvim 处理添加到
        -- opts.appearance.kind_icons 中 参考默认配置
        -- https://www.lazyvim.org/configuration#default-settings
        -- https://www.lazyvim.org/extras/coding/blink#blinkcmp-1
        -- 参考源码：
        -- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/config/init.lua#L59
        -- https://www.lazyvim.org/extras/coding/blink#blinkcmp
        -- https://github.com/LazyVim/LazyVim/blob/c64a61734fc9d45470a72603395c02137802bc6f/lua/lazyvim/plugins/extras/coding/blink.lua#L163
        kinds = {
          claude = "󰋦",
          openai = "󱢆",
          codestral = "󱎥",
          gemini = "",
          Groq = "",
          Openrouter = "󱂇",
          Ollama = "󰳆",
          ["Llama.cpp"] = "󰳆",
          Deepseek = "",
        },
      },
    },
  },
  -- 提供 ai 补全与 inline hint 补全，类似 copilot 的 ai 补全
  -- https://github.com/milanglacier/minuet-ai.nvim
  {
    "milanglacier/minuet-ai.nvim",
    version = "*",
    event = "BufReadPre",
    dependencies = {
      { "nvim-lua/plenary.nvim" },
    },
    config = function()
      local presets = get_minuet_provider_presets()
      local default_preset_name = get_default_preset_name(presets)
      local opts = {
        virtualtext = {
          -- 默认为所有类型启用 inline 补全，注意小模型不实用
          -- auto_trigger_ft = { "*" },
          -- NOTE: 如果没有任何 LLM 提供会导致输入频繁的触发错误
          auto_trigger_ft = minuet_enabled() and { "lua", "python", "javascript" } or {},
          keymap = {
            -- `A-A` 会影响插入模式下使用 A 到行最后，虽然可以使用 `-A` 代替
            -- 使用 `<Tab>` 会影响插入模式下的 tab 缩进插入
            -- accept whole completion
            accept = "<A-Y>",
            -- accept one line
            accept_line = "<A-a>",
            -- accept n lines (prompts for number)
            -- e.g. "A-z 2 CR" will accept 2 lines
            accept_n_lines = "<A-z>",
            -- Cycle to prev completion item, or manually invoke completion
            prev = "<A-[>",
            -- Cycle to next completion item, or manually invoke completion
            next = "<A-]>",
            dismiss = "<A-e>",
          },
        },
        presets = presets,
      }
      -- vim.notify("opts=" .. vim.inspect(opts), vim.log.levels.INFO)
      local minuet = require("minuet")
      minuet.setup(opts)

      -- 启用默认的 preset
      if default_preset_name then
        minuet.change_preset(default_preset_name)
        minuet_preset_inited = true
      end
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      -- https://github.com/milanglacier/minuet-ai.nvim#integration-with-lazyvim
      keymap = {
        -- 在插入模式下刷新补全
        ["<A-y>"] = {
          function(cmp)
            if minuet_enabled() then
              cmp.show({ providers = { "minuet" } })
            end
          end,
        },
      },
      sources = {
        -- if you want to use auto-complete
        default = { "minuet" },
        -- https://cmp.saghen.dev/configuration/sources.html#provider-options
        providers = {
          minuet = {
            name = "minuet",
            enabled = minuet_enabled,
            -- 避免 blink.cmp 需要等待 minuet 响应
            async = true,
            timeout_ms = 5000,
            module = "minuet.blink",
            -- 让 minuet 的补全优先级更高，参考默认的 snippets/buffer<0,lsp=0,path=3
            -- https://cmp.saghen.dev/configuration/reference.html#providers
            score_offset = 10,
          },
        },
      },
    },
  },
}
