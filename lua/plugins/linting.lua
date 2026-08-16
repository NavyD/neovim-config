---@type LazySpec
return {
  "mfussenegger/nvim-lint",
  -- 在 nvim-lint 源码中如果直接在
  -- `linters_by_ft={['yaml.ghaction']={some_linters}}` 会让 nvim-lint
  -- 只使用定义的 linters，只有写成 `linters_by_ft={ghaction={some_linters}}`
  -- 才会合并子类型。
  --
  -- 该函数将 `yaml.ghaction=linters` 这种复合类型拆分为 `ghaction=linters`。
  --
  -- 实现参考：
  -- https://github.com/mfussenegger/nvim-lint#usage
  -- https://github.com/LazyVim/LazyVim/blob/459a4c3b1059671e766a46c7cc223827dc67e3d0/lua/lazyvim/plugins/linting.lua#L65
  -- https://github.com/mfussenegger/nvim-lint/blob/a219b2c9e5b4765e5c845aba119dad55806fcaf1/lua/lint.lua#L224
  ---@param opts LazyVimLintOpts
  opts = function(_, opts)
    local ft_linters = opts.linters_by_ft
    if not ft_linters then
      return
    end

    --- 默认是否为复合类型
    local default_compound_ft = true

    -- 文件类型（filetype）映射的“扁平化”处理。 将包含点号（.）
    -- 的复合键（如 "foo.bar"）拆解，把对应的 linter 列表（linters）
    -- 继承给除第一个部分外的所有子部分 {bar=orig_foo_bar.linters}
    ---@alias ftlinters table<string, LazyVimLintOptsFtLinters>
    ---@type table<string, ftlinters>
    local compound_part_ft_linters = vim
      .iter(ft_linters)
      ---@param ft string
      ---@param linters LazyVimLintOptsFtLinters
      :map(
        function(ft, linters)
          ---@type ftlinters
          local part_ft_linters = {}
          -- NOTE: 当 compound_ft==nil 时即使 default_compound_ft=false 整个语句也会返回 false
          local is_compound_ft = linters._compound_ft == nil
              and default_compound_ft
            or linters._compound_ft
          --- NOTE: 移除标志转为 string[]
          linters._compound_ft = nil
          if is_compound_ft then
            part_ft_linters = vim
              .iter(vim.split(ft, ".", { plain = true }))
              -- 跳过 `ft=yaml.ghaction` 中的 yaml 部分，仅选择后续的 ft 类型
              :skip(
                1
              )
              ---@param part_ft string
              :fold(
                {},
                function(acc, part_ft)
                  -- NOTE: 使用引用注意合并时不要修改原表
                  acc[part_ft] = linters
                  return acc
                end
              )
          end
          return ft, part_ft_linters
        end
      )
      -- 跳过非复合 ft 类型
      ---@param v ftlinters
      :filter(
        function(_, v)
          return vim.tbl_count(v) > 0
        end
      )
      ---@param ft string
      ---@param part_ft_linters ftlinters
      :fold(
        {},
        function(acc, ft, part_ft_linters)
          acc[ft] = part_ft_linters
          return acc
        end
      )

    -- 合并复合类型到原 linters 中
    for ft, part_ft_linters in pairs(compound_part_ft_linters) do
      ft_linters[ft] = nil
      for part_ft, linters in pairs(part_ft_linters) do
        -- 合并去重
        ft_linters[part_ft] = vim
          .iter({ ft_linters[part_ft] or {}, linters })
          :flatten()
          :unique()
          :totable()
      end
    end
  end,
}
