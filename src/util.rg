local Exports = {}

local C = terralib.includecstring([[
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
]])

-------------------------------------------------------------------------------
-- Numeric
-------------------------------------------------------------------------------

-- A -> bool
function Exports.isPosInt(x)
  return type(x) == 'number' and x == math.floor(x) and x > 0
end

-------------------------------------------------------------------------------
-- Tables
-------------------------------------------------------------------------------

-- table -> bool
function Exports.isEmpty(tbl)
  if not tbl then
    return true
  end
  for _,_ in pairs(tbl) do
    return false
  end
  return true
end

-- map(K,V) -> K*
function Exports.keys(tbl)
  local res = terralib.newlist()
  for k,v in pairs(tbl) do
    res:insert(k)
  end
  return res
end

-- T*, (T -> bool) -> bool
function Exports.all(list, pred)
  assert(terralib.israwlist(list))
  for _,x in ipairs(list) do
    if not pred(x) then return false end
  end
  return true
end

-- T*, (T -> bool) -> bool
function Exports.any(list, pred)
  assert(terralib.israwlist(list))
  for _,x in ipairs(list) do
    if pred(x) then return true end
  end
  return false
end

-- table -> table
function Exports.copyTable(tbl)
  local cpy = {}
  for k,v in pairs(tbl) do cpy[k] = v end
  return cpy
end

-- table -> int
function Exports.tableSize(tbl)
  local size = 0
  for _,_ in pairs(tbl) do
    size = size + 1
  end
  return size
end

-------------------------------------------------------------------------------
-- Lists
-------------------------------------------------------------------------------

local TerraList = getmetatable(terralib.newlist())

-- (T -> bool) -> bool
function TerraList:all(pred)
  return Exports.all(self, pred)
end

-- (T -> bool) -> bool
function TerraList:any(pred)
  return Exports.any(self, pred)
end

-- () -> T*
function TerraList:copy()
  return self:map(function(x) return x end)
end

-- T -> int?
function TerraList:find(x)
  for i,elem in ipairs(self) do
    if elem == x then
      return i
    end
  end
  return nil
end

-- () -> set(T)
function TerraList:toSet()
  local set = {}
  for _,elem in ipairs(self) do
    set[elem] = true
  end
  return set
end

-- string? -> string
function TerraList:join(sep)
  sep = sep or ' '
  local res = ''
  for i,elem in ipairs(self) do
    if i > 1 then
      res = res..sep
    end
    res = res..tostring(elem)
  end
  return res
end

-- () -> T*
function TerraList:reverse()
  local res = terralib.newlist()
  for i = #self, 1, -1 do
    res:insert(self[i])
  end
  return res
end

-- () -> T
function TerraList:pop()
  local res = self[#self]
  self[#self] = nil
  return res
end

-- int, (() -> T) -> T*
function Exports.generate(n, generator)
  local res = terralib.newlist()
  for i = 1,n do
    res:insert(generator())
  end
  return res
end

-------------------------------------------------------------------------------
-- Strings
-------------------------------------------------------------------------------

-- string -> string*
function string:split(sep)
  local fields = terralib.newlist()
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields:insert(c) end)
  return fields
end

-- string -> bool
function string:startswith(subStr)
  return self:sub(1, subStr:len()) == subStr
end

-- string -> bool
function string:endswith(subStr)
  return self:sub(self:len() - subStr:len() + 1, self:len()) == subStr
end

-------------------------------------------------------------------------------
-- Terra type helpers
-------------------------------------------------------------------------------

-- {string,terralib.type} | {field:string,type:terralib.type} ->
--   string, terralib.type
function Exports.parseStructEntry(entry)
  if terralib.israwlist(entry)
  and #entry == 2
  and type(entry[1]) == 'string'
  and terralib.types.istype(entry[2]) then
    return entry[1], entry[2]
  elseif type(entry) == 'table'
  and entry.field
  and entry.type then
    return entry.field, entry.type
  else assert(false) end
end

-- map(terralib.type,string)
local cBaseType = {
  [int]    = 'int',
  [int8]   = 'int8_t',
  [int16]  = 'int16_t',
  [int32]  = 'int32_t',
  [int64]  = 'int64_t',
  [uint]   = 'unsigned',
  [uint8]  = 'uint8_t',
  [uint16] = 'uint16_t',
  [uint32] = 'uint32_t',
  [uint64] = 'uint64_t',
  [bool]   = 'bool',
  [float]  = 'float',
  [double] = 'double',
}

-- terralib.type, bool, string -> string, string
local function typeDecl(typ, cStyle, indent)
  if typ:isarray() then
    local decl, mods = typeDecl(typ.type, cStyle, indent)
    decl = cStyle and decl or decl..'['..tostring(typ.N)..']'
    mods = cStyle and '['..tostring(typ.N)..']'..mods or mods
    return decl, mods
  elseif typ:isstruct() then
    return Exports.prettyPrintStruct(typ, cStyle, indent), ''
  elseif typ:isprimitive() then
    return (cStyle and cBaseType[typ] or tostring(typ)), ''
  else assert(false) end
end

-- terralib.struct, bool?, string? -> string
function Exports.prettyPrintStruct(s, cStyle, indent)
  indent = indent or ''
  local lines = terralib.newlist()
  local isUnion = false
  local entries = s.entries
  if #entries == 1 and terralib.israwlist(entries[1]) then
    isUnion = true
    entries = entries[1]
  end
  local name = s.name:startswith('anon') and '' or s.name
  local open =
    (cStyle and isUnion)         and ('union '..name..' {')          or
    (cStyle and not isUnion)     and ('struct '..name..' {')         or
    (not cStyle and isUnion)     and ('struct '..name..' { union {') or
    (not cStyle and not isUnion) and ('struct '..name..' {')         or
    assert(false)
  lines:insert(open)
  for _,e in ipairs(entries) do
    local name, typ = Exports.parseStructEntry(e)
    local s1 = cStyle and '' or (name..' : ')
    local s3 = cStyle and (' '..name) or ''
    local s2, s4 = typeDecl(typ, cStyle, indent..'  ')
    lines:insert(indent..'  '..s1..s2..s3..s4..';')
  end
  local close =
    (cStyle and isUnion)         and '}'   or
    (cStyle and not isUnion)     and '}'   or
    (not cStyle and isUnion)     and '} }' or
    (not cStyle and not isUnion) and '}'   or
    assert(false)
  lines:insert(indent..close)
  return lines:join('\n')
end

-------------------------------------------------------------------------------
-- Filesystem
-------------------------------------------------------------------------------

terra Exports.createDir(name : &int8)
  var mode = 493 -- octal 0755 = rwxr-xr-x
  var res = C.mkdir(name, mode)
  if res < 0 then
    var stderr = C.fdopen(2, 'w')
    C.fprintf(stderr, 'Cannot create directory %s: ', name)
    C.fflush(stderr)
    C.perror('')
    C.fflush(stderr)
    C.exit(1)
  end
end

terra Exports.openFile(name : &int8, mode : &int8) : &C.FILE
  var file = C.fopen(name, mode)
  if file == nil then
    var stderr = C.fdopen(2, 'w')
    C.fprintf(stderr, 'Cannot open file %s in mode "%s": ', name, mode)
    C.fflush(stderr)
    C.perror('')
    C.fflush(stderr)
    C.exit(1)
  end
  return file
end

-------------------------------------------------------------------------------

return Exports
