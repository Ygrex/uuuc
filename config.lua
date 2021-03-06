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

-- width x height of pics
-- aspect ratio will be preserved
-- set {-1, -1} for original size
PIX = {48, 48};
-- directory with icons
PIXDIR = "./pics";
-- default icon
PIX_NONE = "emblem-symbolic-link.png";

-- tool to open any URL
EXEC = "xdg-open";

