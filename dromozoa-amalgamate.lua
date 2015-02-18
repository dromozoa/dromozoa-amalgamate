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

local searcher1 = package.searchers[1]
local searcher2 = package.searchers[2]
local searcher3 = package.searchers[3]
local searcher4 = package.searchers[4]

local traced = {}
local trace = function (name, mode, a, ...)
  if type(a) == "function" then
    traced[#traced + 1] = {
      mode = mode;
      name = name;
      path = select(-1, ...)
    }
  end
  return a, ...
end

package.searchers[2] = function (name, ...)
  return trace(name, 2, searcher2(name, ...))
end

package.searchers[3] = function (name, ...)
  return trace(name, 3, searcher3(name, ...))
end

package.searchers[4] = function (name, ...)
  return trace(name, 4, searcher4(name, ...))
end

local json = require "dromozoa.json"
require "dromozoa.json.pointer"
local posix = require "posix"

print(json.encode(traced))
