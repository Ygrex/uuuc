#!/usr/bin/env lua5.1

--require "rex_pcre";

-- load the config
dofile("config.lua");

-- {{{ includes
local sqlite3 = require "sql";
assert(type(sqlite3) == "table");
local guuc = require "guuc";
assert(type(guuc) == "table");
-- }}} includes

local main = function()
	local sql, e = sqlite3.Sqlite3:new(DB);
	assert(sql ~= nil, e);
	local guuc, e = guuc.Guuc:new(sql);
	assert(guuc ~= nil, e);
	guuc:loop();
	return 0;
end;

local r = main();
main = nil;
sqlite3 = nil;
collectgarbage("collect");
--os.exit(r);
return r;

-- vim: set foldmethod=marker:
