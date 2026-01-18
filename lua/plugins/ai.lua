local source_icons = {
  minuet = "󱗻",
  orgmode = "",
  otter = "󰼁",
  nvim_lsp = "",
  lsp = "",
  buffer = "",
  luasnip = "",
  snippets = "",
  path = "",
  git = "",
  tags = "",
  cmdline = "󰘳",
  latex_symbols = "",
  cmp_nvim_r = "󰟔",
  codeium = "󰩂",
  -- FALLBACK
  fallback = "󰜚",
}

local provider_presets = {
  deepseek = {
    provider = "openai_fim_compatible",
    context_window = 4000,
    provider_options = {
      openai_fim_compatible = {
        api_key = "MINUETAI_PROVIDER_DEEPSEEK_API_KEY",
        name = "deepseek",
        optional = {
          max_tokens = 256,
          top_p = 0.9,
        },
      },
    },
  },
  ollama = {
    provider = "openai_fim_compatible",
    n_completions = 1, -- recommend for local model for resource saving
    -- I recommend beginning with a small context window size and incrementally
    -- expanding it, depending on your local computing power. A context window
    -- of 512, serves as an good starting point to estimate your computing
    -- power. Once you have a reliable estimate of your local computing power,
    -- you should adjust the context window to a larger value.
    -- context_window = 512,
    context_window = 512,
    -- 增加请求时间
    request_timeout = 10,
    provider_options = {
      openai_fim_compatible = {
        -- For Windows users, TERM may not be present in environment variables.
        -- Consider using APPDATA instead.
        -- api_key = vim.fn.has("win32") == 1 and "USERPROFILE" or "TERM",
        api_key = function()
          return "sk-no_auth"
        end,
        name = "Ollama",
        end_point = vim.env.MINUETAI_PROVIDER_OLLAMA_END_POINT,
        model = vim.env.MINUETAI_PROVIDER_OLLAMA_MODEL or "qwen2.5-coder:1.5b",
        -- only send the request every x milliseconds, use 0 to disable throttle.
        throttle = 800,
        -- debounce the request in x milliseconds, set to 0 to disable debounce
        debounce = 200,
        optional = {
          max_tokens = 32,
          top_p = 0.9,
        },
      },
    },
  },
}

local default_provider_preset = nil
if vim.env[provider_presets.deepseek.provider_options.openai_fim_compatible.api_key] then
  default_provider_preset = "deepseek"
elseif provider_presets.ollama.provider_options.openai_fim_compatible.end_point then
  default_provider_preset = "ollama"
else
  -- 如果不存在可用的 ai 补全源，则不启用直接返回，避免补全功能频繁提示错误信息
  return {}
end

---@module 'lazy'
---@type LazyPluginSpec[]
return {
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
      require("minuet").setup({
        virtualtext = {
          -- 默认为所有类型启用 inline 补全，注意小模型不实用
          auto_trigger_ft = { "*" },
          keymap = {
            -- `A-A` 会影响插入模式下使用 A 到行最后，虽然可以使用 `-A` 代替
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
        presets = provider_presets,
      })
      require("minuet").change_preset(default_provider_preset)
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "normal",
        kind_icons = {
          -- LLM Provider icons
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
      completion = {
        menu = {
          draw = {
            columns = {
              { "label", "label_description", gap = 1 },
              { "kind_icon", "kind" },
              { "source_icon" },
            },
            components = {
              source_icon = {
                -- don't truncate source_icon
                ellipsis = false,
                text = function(ctx)
                  return source_icons[ctx.source_name:lower()] or source_icons.fallback
                end,
                highlight = "BlinkCmpSource",
              },
            },
          },
        },
      },
      -- https://github.com/milanglacier/minuet-ai.nvim#integration-with-lazyvim
      keymap = {
        -- 在插入模式下刷新补全
        ["<A-y>"] = {
          function(cmp)
            cmp.show({ providers = { "minuet" } })
          end,
        },
      },
      sources = {
        -- if you want to use auto-complete
        default = { "minuet" },
        providers = {
          minuet = {
            name = "minuet",
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
