-- Copyright (C) 2015 Tomoyuki Fujimori <moyu@dromozoa.com>
--
-- This file is part of dromozoa-amalgamate.
--
-- dromozoa-amalgamate is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- dromozoa-amalgamate is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with dromozoa-amalgamate.  If not, see <http://www.gnu.org/licenses/>.

local format = string.format
local unpack = table.unpack

local output
local source_module = {}
local source_script

local i = 1
while i <= #arg do
  local a, b = arg[i], arg[i + 1]
  if a == "-o" then
    output = b
    i = i + 2
  elseif a == "-r" then
    source_module[#source_module+ 1] = b
    i = i + 2
  elseif a == "-s" then
    source_script = b
    i = i + 2
  elseif a == "--" then
    i = i + 1
    break
  else
    break
  end
end
local index = i

local searchers = {}
for i = 2, #package.searchers do
  searchers[i] = package.searchers[i]
end

local exit = os.exit
local exit_success = { "EXIT_SUCCESS" }
local exit_failure = { "EXIT_FAILURE" }

local required_module = {}

local function searcher_filter(index, name, loader, ...)
  if type(loader) == "function" then
    required_module[#required_module + 1] = {
      index = index;
      name = name;
      path = select(-1, ...);
    }
  end
  return loader, ...
end

local function searcher(index)
  return function (name, ...)
    return searcher_filter(index, name, searchers[index](name, ...))
  end
end

for i = 2, #package.searchers do
  package.searchers[i] = searcher(i)
end

local function exit_success() end
local function exit_failure() end

os.exit = function (code)
  if code == nil or code == 0 then
    error(exit_success)
  else
    error(exit_failure)
  end
end

for i = 1, #source_module do
  local result, message = pcall(require, source_module[i])
  assert(result or message == exit_success)
end
if source_script ~= nil then
  local result, message = pcall(assert(loadfile(source_script)), unpack(arg, index))
  assert(result or message == exit_success)
end

for i = 2, #package.searchers do
  package.searchers[i] = searchers[i]
end
os.exit = exit

local function read_code(path)
  local handle = assert(io.open(path))
  local code = handle:read("*a"):gsub("^#!.-\n", ""):gsub("^%s+", ""):gsub("%s+$", "")
  handle:close()
  return code
end

local out
if output == nil then
  out = io.stdout
else
  out = assert(io.open(output, "w"))
end

if source_script ~= nil then
  out:write("#! /usr/bin/env lua\n")
end

for i = 1, #required_module do
  local v = required_module[i]
  if v.index == 2 then
    out:write(string.format([[
package.loaded[%q] = (function ()
-- ===========================================================================
%s
-- ===========================================================================
end)()
]], v.name, read_code(v.path)))
  end
end

if source_script ~= nil then
  out:write(string.format([[
-- ===========================================================================
%s
-- ===========================================================================
]], read_code(source_script)))
end

out:close()
