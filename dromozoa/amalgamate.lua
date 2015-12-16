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

local loadstring = require "dromozoa.commons.loadstring"
local read_file = require "dromozoa.commons.read_file"
local searchpath = require "dromozoa.commons.searchpath"
local sequence = require "dromozoa.commons.sequence"
local sequence_writer = require "dromozoa.commons.sequence_writer"
local unpack = require "dromozoa.commons.unpack"

local exit_success = function () end

local function copy(this, that)
  for k, v in pairs(that) do
    this[k] = v
  end
  return this
end

local function remove_hashbang(script)
  return (script:gsub("^%#%![^\n]*\n", ""))
end

local class = {}

if _VERSION >= "Lua 5.2" then
  class.searchers = package.searchers
else
  class.searchers = package.loaders
end

function class.new()
  return class.save({
    stack = sequence():push({
      require = sequence();
      loader = sequence();
    })
  })
end

function class:save()
  self.context = {
    arg = copy({}, arg);
    searchers = copy({}, class.searchers);
    require = require;
    exit = os.exit;
  }
  return self
end

function class:restore()
  local context = self.context
  copy(arg, context.arg)
  copy(class.searchers, context.searchers)
  require = context.require
  os.exit = context.exit
end

function class:parse_arg()
  local out = sequence_writer()
  local output

  arg[-1] = "lua"
  arg[0] = nil

  local i = 1
  local n = #arg
  while i <= n do
    local a, b = arg[i], arg[i + 1]
    local c = a:match("^%-(.*)")
    if c == nil then
      local handle = assert(io.open(a))
      out:write(remove_hashbang(handle:read("*a")))
      arg[0] = a
      i = i + 1
    else
      if c == "e" then
        out:write(b, "\n")
        i = i + 2
      elseif c == "l" then
        out:write(("_ENV[%q] = require(%q)\n"):format(b, b))
        i = i + 2
      elseif c == "-" then
        i = i + 1
        break
      elseif c == "" then
        out:write(remove_hashbang(io.read("*a")))
        arg[0] = "-"
        i = i + 1
        break
      elseif c == "o" then
        output = b
        i = i + 2
      else
        error("unrecognized option '" .. a .. "'")
      end
    end
  end

  local j = 0
  for i = i, n do
    j = j + 1
    arg[j] = arg[i]
  end
  for i = j + 1, n do
    arg[i] = nil
  end

  self.script = out:concat()
  self.output = output
  return self
end

local function searcher(stack, modname, loader, filename, ...)
  if type(loader) == "function" then
    if filename == nil then
      filename = searchpath(modname, package.path)
    end
    if filename ~= nil and filename:find("%.lua$") then
      stack:top().loader:push({
        modname = modname;
        filename = filename;
      })
    end
  end
  return loader, filename, ...
end

function class:setup_searchers()
  local stack = self.stack
  for k, v in pairs(class.searchers) do
    class.searchers[k] = function (modname, ...)
      return searcher(stack, modname, v(modname, ...))
    end
  end
  return self
end

function class:setup_require()
  local stack = self.stack
  local context = self.context
  require = function (modname)
    local this = {
      modname = modname;
      require = sequence();
      loader = sequence();
    }
    stack:top().require:push(this)
    stack:push(this)
    local result = context.require(modname)
    stack:pop()
    return result
  end
  return self
end

function class:setup_exit()
  local context = self.context
  os.exit = function (code)
    if code == nil or code == 0 then
      error(exit_success)
    else
      context.exit(code)
    end
  end
  return self
end

function class:eval()
  local result, message = pcall(assert(loadstring(self.script)), unpack(arg))
  if not result and message ~= exit_success then
    error(message)
  end
  return self
end

local function write(out, this)
  for v in this.require:each() do
    write(out, v)
  end
  for v in this.loader:each() do
    out:write("dromozoa_amalgamate_loaded = true\n")
    out:write(("package.loaded[%q] = (function ()\n"):format(v.modname))
    out:write(remove_hashbang(read_file(v.filename)))
    out:write("end)()\n")
  end
end

function class:write(out)
  out:write("#! /usr/bin/env lua")
  write(out, self.stack:top())
  out:write(self.script)
end

local metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function ()
    return setmetatable(class.new(), metatable)
  end;
})
