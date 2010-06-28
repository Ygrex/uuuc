#!/usr/bin/env lua

gnome_debug_flags = {"trace", "memory"};

require "rex_pcre";

-- includes
package.cpath = "./unistring/?.so;" .. package.cpath;
require "liblua_unistring";
dofile "getopt.lua";
dofile "guuc.lua";

main = function()
	-- parse command line parameters
	local getopt = Getopt:new();
	getopt:main(arg);
	local guuc = Guuc:new(getopt.sql);
	guuc:main();
end;

main();

-- vim: set foldmethod=marker:
