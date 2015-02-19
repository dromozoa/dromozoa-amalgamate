#! /usr/bin/env lua
local test1 = require "test1"
local test2 = require "test2"
local test3 = require "test3"
local test4 = require "test4"
assert(test1 == 1)
assert(test2 == 2)
assert(test3 == 3)
assert(test4 == 4)
os.exit(0)
