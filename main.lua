#!/usr/bin/env lua

gnome_debug_flags = {"trace", "memory"};

require "gtk";
require "rex_pcre";

-- includes
dofile "getopt.lua";
package.cpath = "./unistring/?.so;" .. package.cpath;
require "liblua_unistring";

main = function()
	-- parse command line parameters
	getopt = Getopt:new();
	getopt:main(arg);
end;

main();

-- vim: set foldmethod=marker:
