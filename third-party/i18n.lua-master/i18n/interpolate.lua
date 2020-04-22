local unpack = unpack or table.unpack -- lua 5.2 compat

-- matches a string of type %{age}
local function interpolateValue(string, variables)
  return string:gsub("(.?)%%{%s*(.-)%s*}",
    function (previous, key)
      if previous == "%" then
        return
      else
        return previous .. tostring(variables [key])
      end
    end)
end

-- matches a string of type %<age>.d
local function interpolateField(string, variables)
  return string:gsub("(.?)%%<%s*(.-)%s*>%.([cdEefgGiouXxsq])",
    function (previous, key, format)
      if previous == "%" then
        return
      else
        return previous .. string.format("%" .. format, variables[key] or "nil")
      end
    end)
end

local DEBUG = false


function print_r ( t )
  local print_r_cache={}
  local function sub_print_r(t,indent)
      if (print_r_cache[tostring(t)]) then
          tprint(indent.."*"..tostring(t))
      else
          print_r_cache[tostring(t)]=true
          if (type(t)=="table") then
              for pos,val in pairs(t) do
                  if (type(val)=="table") then
                      tprint(indent.."["..pos.."] => "..tostring(t).." {")
                      sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                      tprint(indent..string.rep(" ",string.len(pos)+6).."}")
                  elseif (type(val)=="string") then
                      tprint(indent.."["..pos..'] => "'..val..'"')
                  else
                      tprint(indent.."["..pos.."] => "..tostring(val))
                  end
              end
          else
              tprint(indent..tostring(t))
          end
      end
  end
  if (type(t)=="table") then
      tprint(tostring(t).." {")
      sub_print_r(t,"  ")
      tprint("}")
  else
      sub_print_r(t,"  ")
  end
  tprint()
end


local function interpolate(pattern, variables)
  variables = variables or {}
  local result = pattern
  -- tprint(pattern)
  -- print_r(variables)

  result = interpolateValue(result, variables)
  result = interpolateField(result, variables)

  if not DEBUG then
    result = string.format(result, unpack(variables))
  else
    local err, res = pcall(function () result = string.format(result, unpack(variables)) end)

    if err then
      tprint(debug.traceback())
      return(result)
    else
      result = res
    end
  end

  return result
end

return interpolate
