--[[
	shared libraries names
--]]
LIBS = {
	["sqlite3"] = "libsqlite3.so",
};

--[[
	database
--]]
-- DB name
DB = "db.sqlite3";
-- names of tables to use
TBL = {
	["url"] = "url",
	["group"] = "group",
	["prop"] = "prop",
	["item"] = "item",
	["val"] = "val",
};

--[[
	GUI
--]]
-- GTK+ builder file
GLADE_FILE = "uuuc.glade";

-- tool to open any URL
EXEC = "xdg-open";

