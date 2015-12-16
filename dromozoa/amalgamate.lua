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

local empty = require "dromozoa.commons.empty"
local loadstring = require "dromozoa.commons.loadstring"
local read_file = require "dromozoa.commons.read_file"
local searchpath = require "dromozoa.commons.searchpath"
local sequence = require "dromozoa.commons.sequence"
local sequence_writer = require "dromozoa.commons.sequence_writer"
local unpack = require "dromozoa.commons.unpack"

local searchers
if _VERSION >= "Lua 5.2" then
  searchers = package.searchers
else
  searchers = package.loaders
end

local exit_success = function () end

local prolog = [[
local dromozoa_amalgamate_package_loaded = {}
for k, v in pairs(package.loaded) do
  dromozoa_amalgamate_package_loaded[k] = v
end
]]

local function clean(code)
  code = code:gsub("^%#%![^\n]*\n+", "")
  local n = #prolog
  if code:sub(1, n) == prolog then
    code = code:sub(n + 1)
  end
  repeat
    code, n = code:gsub("^%-%-[^\n]*\n+", "")
  until n == 0
  return code
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

local function write(out, u)
  for v in u.require:each() do
    write(out, v)
  end
  for v in u.loader:each() do
    out:write(("package.loaded[%q] = (function ()\n"):format(v.modname))
    out:write(clean(read_file(v.filename)))
    out:write("end)()\n")
  end
end

local class = {}

function class.new()
  return {
    stack = sequence():push({
      require = sequence();
      loader = sequence();
    })
  }
end

function class:setup_arg()
  local out = sequence_writer()

  local i = 1
  local n = #arg
  while i <= n do
    local a, b = arg[i], arg[i + 1]
    local c = a:match("^%-(.*)")
    if c == nil then
      local handle = assert(io.open(a))
      out:write(clean(handle:read("*a")))
      script = a
      i = i + 1
      break
    else
      if c == "e" then
        out:write(b, "\n")
        i = i + 2
      elseif c == "l" then
        out:write(("_G[%q] = require(%q)\n"):format(b, b))
        i = i + 2
      elseif c == "-" then
        i = i + 1
        break
      elseif c == "" then
        out:write(clean(io.read("*a")))
        script = "-"
        i = i + 1
        break
      elseif c == "o" then
        self.output = b
        i = i + 2
      else
        error("unrecognized option '" .. a .. "'")
      end
    end
  end

  arg[-1] = "lua"
  arg[0] = script
  local j = 0
  for i = i, n do
    j = j + 1
    arg[j] = arg[i]
  end
  for i = j, n do
    arg[i] = nil
  end

  if empty(out) then
    return nil
  else
    local script = out:concat()
    self.script = script
    return script
  end
end

function class:setup_searchers()
  local stack = self.stack
  for k, v in pairs(searchers) do
    searchers[k] = function (modname, ...)
      return searcher(stack, modname, v(modname, ...))
    end
  end
  return self
end

function class:setup_require()
  local stack = self.stack
  local require = require
  _G.require = function (modname)
    local this = {
      modname = modname;
      require = sequence();
      loader = sequence();
    }
    stack:top().require:push(this)
    stack:push(this)
    local result = require(modname)
    stack:pop()
    return result
  end
end

function class:setup_exit()
  local exit = os.exit
  os.exit = function (code)
    if code == nil or code == 0 then
      error(exit_success)
    else
      exit(code)
    end
  end
  return self
end

function class:eval()
  dromozoa_amalgamate_loading = true
  local result, message = pcall(assert(loadstring(self.script)), unpack(arg))
  dromozoa_amalgamate_loading = nil
  if not result and message ~= exit_success then
    error(message)
  end
  return self
end

function class:write(out)
  out:write("#! /usr/bin/env lua\n", prolog)
  write(out, self.stack:top())
  out:write(self.script)
  return out
end

local metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function ()
    return setmetatable(class.new(), metatable)
  end;
})
