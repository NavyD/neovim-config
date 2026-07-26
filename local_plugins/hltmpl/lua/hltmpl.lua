-- 参考：
-- https://github.com/eggplannt/composite-highlighting.nvim/blob/main/lua/composite-highlighting/main.lua
-- 通过解析复合类型如 base.tmpl 这种作为将 tmpl 语言中注入另一种 base 语言

local fs = vim.fs
local api = vim.api
local fn = vim.fn
local ts = vim.treesitter
local filetype = vim.filetype
local ts_query = ts.query
local ts_lang = ts.language
local fnamemodify = fn.fnamemodify

local log = require("utils.log").new()

---@class hltmpl.Language
---@field injection_node string
---@field language string

---@class hltmpl.Injection
---@field node string treesitter 注入点
---对于已存在的 ft 类型中的哪些 outer 文件类型需要注入
---@field filetypes string[]?
---@field language string? 注入的语言。默认为文件类型

---@class hltmpl.Opts
---@field injections hltmpl.Injection[]?

---@class hltmpl.Config
---对于已存在的 ft 类型中的哪些 outer 文件类型对应需要注入的 language
---@field filetype_langs table<string, hltmpl.Language>

local M = {}

---@type hltmpl.Config
M.config = { filetype_langs = {} }

---@param ft string
---@diagnostic disable-next-line
local function get_injection_lang(ft)
  local ft_stem = fnamemodify(ft, ":r")
  if ft_stem == ft then
    return
  end
  return ts_lang.get_lang(ft_stem)
end

local function inject_ts()
  -- 注册指令（只需一次）
  ts_query.add_directive("inject-composite!", function(_, _, source, _, metadata)
    if type(source) ~= "number" then
      return
    end
    local inner_lang = get_injection_lang(vim.bo[source].filetype)
    if not inner_lang then
      return
    end
    log.debug("set metadata injection.language", inner_lang, "for path", api.nvim_buf_get_name(source))
    metadata["injection.language"] = inner_lang
  end, {})

  local inj_languages = {}
  for _, lang_config in pairs(M.config.filetype_langs) do
    local base_lang = lang_config.language

    -- 跳过重复的 lang 注入
    if inj_languages[base_lang] then
      goto continue
    end

    -- 加载解析器
    local load_ok, load_err = ts_lang.add(base_lang)
    if not load_ok then
      log.error("Failed to load lang", base_lang, ":", load_err)
      goto continue
    end

    -- 设置注入查询（每个语言一次，多组合共享指令）
    local node = lang_config.injection_node
    local query_text = string.format(
      [[
    ((%s) @injection.content
      (#inject-composite!)
      (#set! injection.combined))
  ]],
      node
    )

    local query_name = "injections"
    -- 获取已有查询文件路径列表，合并追加
    local old_inj_files = ts_query.get_files(base_lang, query_name)
    if #old_inj_files > 0 then
      log.debug("get old injections in files", old_inj_files)
      -- 内置的注入规则继续生效，用户不会丢失原有高亮
      local old_inj_queries = vim
        .iter(old_inj_files)
        :map(function(path)
          return table.concat(fn.readfile(path), "\n")
        end)
        :totable()
      -- 添加新 query 到最后
      table.insert(old_inj_queries, query_text)
      query_text = table.concat(old_inj_queries, "\n")
    end

    log.debug("setting treesitter lang", base_lang, "for query", query_name)
    ts_query.set(base_lang, query_name, query_text)

    -- 标志 lang 已注入
    inj_languages[base_lang] = true

    ::continue::
  end
end

---@type string[]
local orig_paths = {}

---@param path string
---@param bufnr integer?
local function match_composite_ft(path, bufnr)
  -- 避免同时多个 buf 打开时并发导致只运行一个的问题
  local orig_path_idx = bufnr
  if not orig_path_idx or orig_path_idx < 0 then
    orig_path_idx = 0
  end
  -- 防递归：如果已有顶层路径且当前路径不同，说明是内部调用
  -- 对一个 path 只运行一次，返回 nil 让其它低优先级的 filetype 判断
  if orig_paths[orig_path_idx] then
    return nil
  end
  -- 首次调用
  orig_paths[orig_path_idx] = path

  -- 用 pcall 执行核心检测逻辑，确保异常时也能清理状态
  local ok, ft = pcall(function()
    local outer_ext = fs.ext(path)
    if outer_ext == "" then
      return nil
    end

    local stem1 = fnamemodify(path, ":r")
    if stem1 == path then
      return nil
    end

    local stem2 = fnamemodify(stem1, ":r")

    local outer_path = nil
    -- 只有一个后缀时使用虚拟的固定文件名如 /dir/file.ext
    -- 基本只检查后缀
    if stem1 == stem2 then
      outer_path = fs.joinpath(fs.dirname(stem2), "file." .. outer_ext)
    else
      -- 多个后缀时检查 inner_ft 时的文件 ft 如 afile.yaml.j2 -> afile.j2
      outer_path = stem2 .. "." .. outer_ext
    end

    -- bufnr 可能为 -1 非法时不传递
    if not bufnr or not api.nvim_buf_is_valid(bufnr) then
      bufnr = nil
    end
    local outer_ft = filetype.match({ filename = outer_path, buf = bufnr })
    log.debug("got outer_ft", outer_ft, "for path", outer_path)
    -- 未配置时跳过
    if not outer_ft or not M.config.filetype_langs[outer_ft] then
      return nil
    end

    -- 获取无 outer_ft 的文件类型如 afile.yaml.j2 -> a.file.yaml，或 Makefile
    local inner_ft = filetype.match({ filename = stem1, buf = bufnr })
    log.debug("got inner_ft", inner_ft, "for path", stem1)
    if not inner_ft then
      return nil
    end

    return table.concat({ inner_ft, outer_ft }, ".")
  end)

  -- 重置状态
  orig_paths[orig_path_idx] = nil

  -- 如果 pcall 捕获到异常，记录日志并返回 nil（不生成复合类型）
  if not ok then
    log.error("Error in composite filetype detection: " .. tostring(ft))
    return nil
  end

  log.debug("matched composite ft", ft, "for path", path)
  return ft
end

---@param opts hltmpl.Opts
local function setup_config(opts)
  M.config.filetype_langs = vim.iter(opts.injections or {}):fold(
    {},
    ---@param inj hltmpl.Injection
    function(acc, inj)
      local fts = inj.filetypes
      if not fts then
        if not inj.language then
          log.error("invalid injection", inj)
          return acc
        end
        fts = { inj.language }
      end

      for _, ft in ipairs(fts) do
        if acc[ft] then
          log.warn("found duplicate ft", ft, acc[ft], "for injection_lang", inj)
        else
          local lang = inj.language or ts_lang.get_lang(ft) or ft
          acc[ft] = {
            injection_node = inj.node,
            language = lang,
          }
        end
      end
      return acc
    end
  )
end

---@param opts hltmpl.Opts?
function M.setup(opts)
  opts = opts or {}

  api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      setup_config(opts)

      filetype.add({
        pattern = {
          [".+%..+"] = {
            match_composite_ft,
            -- 保证优先使用这个函数检查，让函数调用其它 ft 配置递归决定 ft
            -- NOTE: huge=inf, huge - 1 = inf，必须配置非 inf 才能比较优先级
            { priority = 2 ^ 30 },
          },
        },
      })

      vim.schedule(inject_ts)
    end,
  })

  api.nvim_create_autocmd("FileType", {
    pattern = "*.*",
    callback = function(args)
      local ft = args.match
      local outer_ft = fs.ext(ft)
      if outer_ft == "" then
        return
      end
      local ft_lang = M.config.filetype_langs[outer_ft]
      if not ft_lang then
        return
      end

      local lang = ft_lang.language
      -- 确保解析器已加载
      local load_ok, load_err = ts_lang.add(lang)
      if not load_ok then
        log.error("Failed to load lang", lang, "for ft", outer_ft, ":", load_err)
        return
      end
      -- 关联复合类型 ft 让其使用 outer_ft 的语言显示
      ts_lang.register(lang, { ft })
    end,
  })
end

return M
