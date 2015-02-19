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
local module = {}
local script

local i = 1
while i <= #arg do
  local a, b = arg[i], arg[i + 1]
  if a == "-o" then
    output = b
    i = i + 2
  elseif a == "-r" then
    module[#module+ 1] = b
    i = i + 2
  elseif a == "-s" then
    script = b
    i = i + 2
  elseif a == "--" then
    i = i + 1
    break
  else
    break
  end
end
local index = i

local backup ={
  require = require;
  package = { searchers = {} };
  os = { exit = os.exit };
}
for i = 2, #package.searchers do
  backup.package.searchers[i] = package.searchers[i]
end

local stack = {
  {
    required = {};
    loaded = {};
  };
}

require = function (name)
  local required = stack[#stack].required
  required[#required + 1] = {
    name = name;
    required = {};
    loaded = {};
  }
  stack[#stack + 1] = required[#required]
  local result = backup.require(name)
  stack[#stack] = nil;
  return result
end

local function searcher_result(index, name, loader, ...)
  if type(loader) == "function" then
    local loaded = stack[#stack].loaded
    loaded[#loaded + 1] = {
      index = index;
      name = name;
      path = select(-1, ...);
    }
  end
  return loader, ...
end

local function searcher(index)
  return function (name, ...)
    return searcher_result(index, name, backup.package.searchers[index](name, ...))
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

for i = 1, #module do
  local result, message = pcall(require, module[i])
  assert(result or message == exit_success, message)
end
if script ~= nil then
  local result, message = pcall(assert(loadfile(script)), unpack(arg, index))
  assert(result or message == exit_success, message)
end

require = backup.require
for i = 2, #package.searchers do
  package.searchers[i] = backup.package.searchers[i]
end
os.exit = backup.os.exit

local out
if output == nil then
  out = io.stdout
else
  out = assert(io.open(output, "w"))
end

local function amalgamate(path)
  local handle = assert(io.open(path))
  out:write("--------------------------------------------------------------------------------\n")
  out:write(handle:read("*a"):gsub("^#!.-\n", ""):gsub("^%s+", ""):gsub("%s+$", ""), "\n")
  out:write("--------------------------------------------------------------------------------\n")
  handle:close()
end

local function amalgamate_module(this)
  local required = this.required
  for i = 1, #required do
    local v = required[i]
    amalgamate_module(required[i])
  end
  local loaded = this.loaded
  for i = 1, #loaded do
    local v = loaded[i]
    if v.index == 2 then
      out:write(format("package.loaded[%q] = (function ()\n", v.name))
      amalgamate(v.path)
      out:write("end)()\n")
    end
  end
end

if script == nil then
  amalgamate_module(stack[1])
else
  out:write("#! /usr/bin/env lua\n")
  amalgamate_module(stack[1])
  amalgamate(script)
end
