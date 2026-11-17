-- KDoc skeleton: <CR> after a lone `/**` expands to a comment with @param / @return filled in
-- from the function or class below. See docblock.lua.
local docblock = require 'custom.snippets.docblock'
local text = docblock.node_text

local function names(list, child_type, src, out, prefix)
  for c in list:iter_children() do
    if c:type() == child_type then
      local id = c:named_child(0)
      -- parameter / class_parameter: the name is the simple_identifier (after `val`/`var` if present)
      for n in c:iter_children() do
        if n:type() == 'simple_identifier' then
          id = n
          break
        end
      end
      table.insert(out, prefix .. text(id, src))
    end
  end
end

local function tags_for(decl_text)
  local out = {}
  local src = decl_text
  local root = vim.treesitter.get_string_parser(src, 'kotlin'):parse()[1]:root()
  local decl
  for child in root:iter_children() do
    if child:type():match '_declaration$' then
      decl = child
      break
    end
  end
  if not decl then
    return out
  end

  local function find(ty)
    for c in decl:iter_children() do
      if c:type() == ty then
        return c
      end
    end
  end

  local tp = find 'type_parameters'
  if tp then
    names(tp, 'type_parameter', src, out, '@param ')
  end

  if decl:type() == 'function_declaration' then
    local params = find 'function_value_parameters'
    if params then
      names(params, 'parameter', src, out, '@param ')
      -- a return type is a type node between the parameter list and the body
      local after = false
      for c in decl:iter_children() do
        if c == params or c:id() == params:id() then
          after = true
        elseif after and c:named() and c:type() ~= 'function_body' and c:type() ~= 'type_constraints' then
          if text(c, src) ~= 'Unit' then
            table.insert(out, '@return')
          end
          break
        end
      end
    end
  elseif decl:type() == 'class_declaration' then
    local ctor = find 'primary_constructor'
    if ctor then
      names(ctor, 'class_parameter', src, out, '@param ')
    end
  end
  return out
end

return { tags_for = tags_for }
