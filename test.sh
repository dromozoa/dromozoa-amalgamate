#! /bin/sh -e

lua dromozoa-amalgamate.lua -s test.lua | env LUA_PATH= LUA_CPATH= lua
