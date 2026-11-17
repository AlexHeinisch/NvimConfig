-- Javadoc skeleton: <CR> after a lone `/**` (above a method, constructor, class, ...)
-- expands to a comment with @param / @return / @throws filled in from the declaration below,
-- like IntelliJ's `/**` + Enter (the <CR> hook lives in plugins/blink.lua, logic in docblock.lua).
local docblock = require 'custom.snippets.docblock'
local text = docblock.node_text

local function tags(decl, src)
  local out = {}
  local function type_params()
    local tp = decl:field('type_parameters')[1]
    if tp then
      for p in tp:iter_children() do
        if p:type() == 'type_parameter' then
          table.insert(out, '@param <' .. text(p:named_child(0), src) .. '>')
        end
      end
    end
  end
  local function params(list)
    if not list then
      return
    end
    for p in list:iter_children() do
      local ty = p:type()
      if ty == 'formal_parameter' or ty == 'spread_parameter' then
        local name = p:field('name')[1]
        if not name then -- spread_parameter keeps the name in a variable_declarator
          for c in p:iter_children() do
            if c:type() == 'variable_declarator' then
              name = c:field('name')[1]
            end
          end
        end
        if name then
          table.insert(out, '@param ' .. text(name, src))
        end
      end
    end
  end

  local ty = decl:type()
  if ty == 'method_declaration' or ty == 'constructor_declaration' then
    type_params()
    params(decl:field('parameters')[1])
    local rt = decl:field('type')[1]
    if rt and rt:type() ~= 'void_type' then
      table.insert(out, '@return')
    end
    for c in decl:iter_children() do
      if c:type() == 'throws' then
        for e in c:iter_children() do
          if e:named() then
            table.insert(out, '@throws ' .. text(e, src))
          end
        end
      end
    end
  elseif ty == 'record_declaration' then
    type_params()
    params(decl:field('parameters')[1])
  elseif ty == 'class_declaration' or ty == 'interface_declaration' then
    type_params()
  end
  return out
end

local function tags_for(decl_text)
  local src = 'class W {\n' .. decl_text .. '\n}'
  local root = vim.treesitter.get_string_parser(src, 'java'):parse()[1]:root()
  local body = root:named_child(0):field('body')[1]
  for child in body:iter_children() do
    if child:type():match '_declaration$' then
      return tags(child, src)
    end
  end
  return {}
end

return { tags_for = tags_for }
