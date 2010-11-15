local gtk = require "gtk";
assert(type(gtk) == "table", "Error loading GTK module");

local dlffi = gtk.dlffi;
local gtk_t = gtk.typedef;
local g = gtk.g;
local gtk = gtk.gtk;

local Guuc = { _type = "object" };
local Guuc_mt = { __index = Guuc };

-- {{{ bzero(...) - required to initialize GValue s
local _bzero, e = dlffi.load("libc.so.6", "bzero", dlffi.ffi_type_void,
	{
		dlffi.ffi_type_pointer,
		dlffi.ffi_type_size_t,
	}
);
assert(_bzero, e);
local bzero = function(p, n)
	local r, e = _bzero(p, n);
	if e then return nil, e end;
	return p;
end;
-- }}} bzero()

-- {{{ Guuc:new() -- constructor
function Guuc:new(sql)
	if not sql then
		return nil, "Sqlite3 connector must be specified";
	end;
	local o = {
		["sql"] = sql,			-- Sqlite3 connector
		["glade_file"] = GLADE_FILE,	-- glade file to load
		["builder"] = "",		-- GTK builder
		["win"] = "",			-- Url_win
		["list"] = "",			-- Url_treeUrl
		["cb"] = {},			-- callbacks storage to prevent
						-- closures to be GC'ed
		["cl"] = {},			-- storage of closures to cb
	};
	if not o["glade_file"] then
		return nil, "GLADE_FILE is not specified";
	end;
	setmetatable(o, Guuc_mt);
	o.builder = gtk.builder_new();
	if not o.builder then
		return nil, "GtkBuilder initialization failure";
	end;
	local r = o.builder:add_from_file(o.glade_file, dlffi.NULL);
	if (not tonumber(r)) or (r < 1) then
		return nil, "gtk_builder_add_from_file() failed";
	end;
--	local _, e = o.builder:connect_signals(dlffi.NULL);
--	if e then return nil, e end;
	local r, e = o:init();
	if not r then return nil, e end;
	return o;
end;
-- }}} Guuc:new()

-- {{{ Guuc:err(err) -- output an error message
function Guuc:err(err)
	if type(err) == "table" then
		err = table.concat(err, ": ");
	else
		err = tostring(err);
	end;
	print("EE:", err);
end;
-- }}} Guuc:err

-- {{{ Guuc:warn(warn) -- return given error message
function Guuc:warn(warn)
	if type(warn) == "table" then
		warn = table.concat(warn, ": ");
	else warn = tostring(warn) end;
	return nil, warn;
end;
-- }}} Guuc:warn

-- {{{ Guuc:init() -- initialize widgets
function Guuc:init()
	local r, e = self:attach_pop();
	if not r then return nil, e end;
	-- work with Url_win
	local win = self.builder:get_object("Url_win");
	if not win then return nil, "widget Url_win not found" end;
	self.win = win;
	win:connect("destroy", gtk.main_quit);
	-- check the position of Url_hpanUrl
	self:align_hpaned();
	-- work with Url_treeUrl
	local list = self.builder:get_object("Url_treeUrl");
	if not list then return nil, "widget Url_treeUrl not found" end;
	self.list = list;
	local r, e = self:init_tree();
	if not r then return nil, e end;
	-- load GroupHead
	local r, e = self:init_groupHead();
	if not r then return nil, e end;
	-- finalize
	win:show_all();
	return true;
end;
-- }}} Guuc:init

-- {{{ Guuc:attach_pop() -- setup popup menu for Url_treeUrl
function Guuc:attach_pop()
	local me = "attach_pop()";
	local tree = self.builder:get_object("Url_treeUrl");
	if not tree then return nil, "widget Url_treeUrl not found" end;
	local popup = self.builder:get_object("UrlPop_win");
	if not popup then return nil, "widget UrlPop_win not found" end;
	local r,e = self:init_pop();
	if not r then return self:warn{me, "self:init_pop()", e} end;
	-- popup handler
	self.cb.show_popup = function (tree, event)
		local el = dlffi.type_element;
		local button = el(event, gtk_t.GdkEventButton, 9);
		local time = el(event, gtk_t.GdkEventButton, 4);
		-- treat the right button only
		if button ~= 3 then return false end;
		popup:popup(
			dlffi.NULL,	-- parent_menu_shell
			dlffi.NULL,	-- parent_menu_item
			dlffi.NULL,	-- func
			dlffi.NULL,	-- data
			button,		-- button
			time		-- activate_time
		);
		return true;
	end;
	-- listen to the button press event
	self.cl.show_popup = dlffi.load(
		self.cb.show_popup,
		gtk_t.gboolean,
		{
			dlffi.ffi_type_pointer,	-- widget
			dlffi.ffi_type_pointer,	-- event
			dlffi.ffi_type_pointer,	-- user_data
		}
	);
	tree:connect('button_press_event', self.cl.show_popup);
	return true;
end;
-- }}} Guuc:attach_pop

-- {{{ Guuc:load_tree(list) -- load TreeView content from DB
function Guuc:load_tree(list)
	local model = list:get_model();
	if not model then
		return nil, "load_tree(): TreeModel is undefined";
	end;
	local sql, e = self.sql:new(self.sql.filename);
	if not sql then
		return nil, "load_tree(): " .. tostring(e);
	end;
	local iter = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t.GtkTreeIter),
		true
	);
	local seen = {}; -- appended IDs
	-- {{{ loop(par_id, par_path, unfold) -- loop through URIs
	-- par_id	- ID of theparent node
	-- par_path	- GtkTreePath to the parent node
	local function loop(par_id, par_path, unfold)
		local row, e = sql:fetch_uris(par_id);
		if not row then return nil, e end;
		for i = 1, #row, 1 do
			-- {{{ get the row
			local v = row[i];
			if seen[v[1]] then
				return nil, string.format(
					"load_tree(): recursion on ID %s",
					tostring(v[1])
				);
			end;
			-- }}} get the row
			-- {{{ find the parent's iter
			local par_iter = dlffi.NULL;
			if par_path and (par_path ~= dlffi.NULL) then
				par_iter = dlffi.dlffi_Pointer(
					dlffi.sizeof(gtk_t.GtkTreeIter),
					true
				);
				_bzero(par_iter, dlffi.sizeof(gtk_t.GtkTreeIter));
				local r = model:get_iter(par_iter, par_path);
				if r ~= 1 then
					return nil, string.format(
						"model:get_iter() failed " ..
						"on ID %s",
						tostring(v[1])
					)
				end;
			end;
			-- }}} find the parent's iter
			-- {{{ display the item
			local iter, e = self:item_new(v[1], v[2], par_iter, v[3]);
			if not iter then
				return nil, string.format(
					"load_tree(): append error:: %s",
					tostring(e)
				);
			end;
			seen[v[1]] = true;
			-- }}} display the item
			-- {{{ unfold the parent
			if not par_path then par_path = dlffi.NULL end;
			if (unfold == 1) and (par_path ~= dlffi.NULL) then
				list:expand_row(par_path, false);
			end;
			-- }}} unfold the parent
			-- {{{ find the sub-level items
			local path = model:get_path(iter);
			local r, e = loop(v[1], path, v[3]);
			gtk.tree_path_free(path);
			if not r then return nil, e end;
			-- }}} find the sub-level items
		end;
		return true;
	end;
	-- }}} loop()
	local r, e = loop();
	if not r then return nil, e end;
	return true;
end;
-- }}} Guuc:load_tree

-- {{{ Guuc:init_tree() -- initialize Url_treeUrl
function Guuc:init_tree()
	local list = self.list;
	if not list then return nil, "self.list is undefined" end;
	-- {{{ init columns
	local renderer = gtk.cell_renderer_text_new();
	if not renderer then return nil, "GtkCellRendererText failure" end;
	local col = gtk.tree_view_column_new_with_attributes(
		"URI",
		type(renderer) == "table" and renderer._val or renderer,
		"text", 1,
		dlffi.NULL
	);
	if not col then return nil, "GtkTreeViewColumn failure" end;
	col:set_resizable(true);
	local r = list:append_column(col._val);
	if tonumber(r) ~= 1 then
		return nil, "GtkTreeView column appending failed";
	end;
	-- }}} init columns
	list:get_selection():set_mode(gtk.SELECTION_SINGLE);
	local r, e = self:load_tree(list);
	if not r then return nil, e end;
	-- {{{ expand/collapse listeners
	local unfold_handler = function(tree, iter, path, unfold)
		local me = "unfold_handler()";
		if unfold == dlffi.NULL then unfold = false
		else unfold = true end;
		local model = list:get_model();
		-- {{{ get the item ID
		local id, e;
		id, e = g.value.new();
		if not id then
			return self:err{me, "GValue init failure", e};
		end;
		_, e = model:get_value(iter, 0, id);
		if e then
			return self:err{me, "gtk_tree_model_get_value()", e};
		end;
		id, e = g.value_get_int(id);
		if not id then
			return self:err{me, "g_value_get_int()", e};
		end;
		-- }}} get the item ID
		-- {{{ write to the DB
		local sql, e = self.sql:new(self.sql.filename);
		if not sql then return self:err{me, "ODBC init", e} end;
		local r, e = sql:unfold_uri(id, unfold);
		if not r then return self:err{me, "unfold_uri()", e} end;
		-- }}} write to the DB
		-- {{{ mark in the tree
		local value;
		value, e = g.value.new(gtk.G_TYPE_INT);
		if not value then
			return self:err{me, "GValue(value) failure", e};
		end;
		if unfold then
			_, e = g.value_set_int(value, 1);
		else
			_, e = g.value_set_int(value, 0);
		end;
		if e then
			return self:err{me, "g_value_set_int() failed", e};
		end;
		_, e = model:set_value(iter, 2, value);
		if e then
			return self:err{
				me,
				"GtkTreeStore set_value(value) failed",
				e
			};
		end;
		-- }}} mark in the tree
		-- {{{ unfold children as well
		if unfold then
			-- initialize iterator
			local child = dlffi.dlffi_Pointer(
				dlffi.sizeof(gtk_t.GtkTreeIter),
				true
			);
			-- iterate through children
			if model:iter_children(child, iter) == 1 then repeat
				-- check the `unfold`
				-- get the child's path for expanding
				local path = model:get_path(child);
				if not path then break end;
				local unfold = g.value.new();
				if not unfold then break end;
				local _, e = model:get_value(child, 2, unfold);
				if e then break end;
				unfold = g.value_get_int(unfold);
				if not unfold then break; end;
				if unfold == 1 then
					list:expand_row(path, false);
				else
					list:collapse_row(path);
				end;
				-- model is probably modified, restore iterator
				if model:get_iter(child, path) ~= 1 then
					-- path become broken
					break;
				end;
				gtk.tree_path_free(path);
			until model:iter_next(child) ~= 1 end;
		end;
		-- }}} unfold children as well
		return true;
	end;
	self.cl["unfold_handler"] = dlffi.load(
		unfold_handler,
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		}
	);
	-- prevent local function from being GC'ed
	self.cb["unfold_handler"] = unfold_handler;
	list:connect("row-collapsed",
		self.cl["unfold_handler"],
		dlffi.NULL
	);
	list:connect("row-expanded",
		self.cl["unfold_handler"],
		self.cl["unfold_handler"]
	);
	-- }}} expand/collapse listeners
	-- {{{ selection listener
	local sel = list:get_selection();
	if not sel then
		return nil, "list:get_selection() failed"
	end;
	local on_changed = function(obj, ud)
		local me, e = "on_changed()";
		-- init ODBC
		local sql;
		sql, e = self.sql:new(self.sql.filename);
		if not sql then return self:warn{me, "sql:new()", e} end;
		-- get the ID
		local iter = dlffi.dlffi_Pointer(
			dlffi.sizeof(gtk_t.GtkTreeIter),
			true
		);
		local model = dlffi.dlffi_Pointer();
		local r;
		r, e = sel:get_selected(dlffi.dlffi_Pointer(model), iter);
		if r ~= 1 then
			return self:err {me, "sel:get_selected() ", r, e};
		end;
		model, e = gtk_t(model);
		if not model then
			return self:err {me,
				"sel:get_selected(): no model returned", e};
		end;
		-- fetch the row
		local val;
		val, e = g.value.new();
		if not val then
			return self:err{me, "g.value.new()", e};
		end;
		model:get_value(iter, 0, val);
		val = g.value_get_int(val);
		local uri;
		uri, e = sql:fetch_uri(val);
		if not uri then
			return self:err {me,
				"sql:fetch_uri()", e};
		end;
		model = nil; iter = nil; sql = nil;
		-- fill out properties
		local name;
		name, e = self.builder:get_object("Url_txtName");
		if not name then
			return self:err {
				me, "Url_txtName widget not found", e};
		end;
		local misc;
		misc, e = self.builder:get_object("Url_bufMisc");
		if not misc then
			return self:err {
				me, "Url_bufMisc widget not found", e};
		end;
		-- FIXME verify charset integrity here
		name:set_text(tostring(uri["id"]));
		misc:set_text(uri["misc"], #(uri["misc"]));
		-- activate appropriate group
		self:select_group(uri["group"]);
		return true;
	end;
	self.cb["Url_treeUrl:on_changed"] = on_changed;
	self.cl["Url_treeUrl:on_changed"] = dlffi.load(
		on_changed, dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer }
	);
	sel:connect("changed", self.cl["Url_treeUrl:on_changed"]);
	-- }}} selection listener
	return true;
end;
-- }}} Guuc:init_tree

-- {{{ Guuc:item_new(id, name, parent, unfold) -- add new item to Url_treeUrl
--	return iterator on success
function Guuc:item_new(id, name, parent, unfold)
	local me = "item_new()";
	id = tonumber(id);
	if not id then return self:warn{me, "invalid ID specified"} end;
	local list = self.list;
	if not list then return self:warn{me, "self.list undefined"} end;
	local model = list:get_model();
	if not model then return self:warn{me, "model undefined"} end;
	local iter = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t.GtkTreeIter),
		true
	);
	if not iter then return self:warn{me, "GtkTreeIter init failure"} end;
	if not parent then parent = dlffi.NULL end;
	model:append(iter, parent);
	local gval_id = dlffi.dlffi_Pointer(256, true);
	g.value_init(bzero(gval_id, 256), gtk.G_TYPE_INT);
	local gval_unfold = dlffi.dlffi_Pointer(256, true);
	g.value_init(bzero(gval_unfold, 256), gtk.G_TYPE_INT);
	local gval_name = dlffi.dlffi_Pointer(256, true);
	g.value_init(bzero(gval_name, 256), gtk.G_TYPE_STRING);
	if not tonumber(unfold) then
		if unfold then
			unfold = 1;
		else
			unfold = 0;
		end;
	end;
	g.value_set_int(gval_id, id);
	local _id = g.value_get_int(gval_id);
	g.value_set_int(gval_unfold, unfold);
	local _unfold = g.value_get_int(gval_unfold);
	g.value_set_string(gval_name, name);
	local _name = dlffi.dlffi_Pointer(g.value_get_string(gval_name)):tostring();
	model:set_value(iter, 0, gval_id);
	model:set_value(iter, 1, gval_name);
	model:set_value(iter, 2, gval_unfold);
	return iter;
end;
-- }}} Guuc:item_new

-- {{{ Guuc:get_selected(GtkTreeView) -- return the selected iterator
function Guuc:get_selected(list)
	local sel = list:get_selection();
	local iter = gtk.new("GtkTreeIter");
	local r = sel:get_selected(nil, iter);
	if not r then return nil end;
	return iter;
end;
-- }}} Guuc:get_selected

-- {{{ Guuc:init_pop() -- initialize popup menu for Url_treeUrl
function Guuc:init_pop()
	local me = "init_pop()";
	local UrlPop_new = self.builder:get_object("UrlPop_new");
	if not UrlPop_new then
		return self:warn{me, "menu item UrlPop_new not found"};
	end;
	-- {{{ item_new_clicked -- create new URI
	self.cb.item_new_clicked = function(btn)
		local me = "item_new_clicked()";
		-- {{{ get the parent node
		local list = self.list;
		if not list then
			return self:err { me, "TreeView is not defined" };
		end;
		local sel = self:get_selected(list);
		local path;
		local id = dlffi.NULL;	-- parent ID
		if sel then
			local model = list:get_model();
			if not model then
				return self:err {
					me, "TreeModel is not defined"
				};
			end;
			-- get the parent's ID
			id = model:get_value(sel, 0);
			-- iterator will become invalid after item appending,
			-- store it's path instead
			path = model:get_path(sel);
		end;
		-- }}} get the parent node
		-- {{{ write the item to the DB
		local sql, e = self.sql:new(self.sql.filename);
		if not sql then
			return self:err {
				"item_new_clicked()",
				"ODBC is not defined",
				e
			};
		end;
		local new, e = sql:insert_uri {
			["parent"] = id,
			["misc"] = "new item"
		};
		if not new then
			return self:err {
				"item_new_clicked()",
				e
			};
		end;
		-- }}} write the item to the DB
		-- {{{ display the item on the Url_treeUrl
		local r, e = self:item_new(new, "new item", sel);
		if not r then
			return self:err {me, "no iterator returned", e};
		end;
		if path then
			-- unfold the parent item
			list:expand_row(path, false);
			path:free();
		end;
		-- select the item
		sel:select_iter(r);
		-- }}} display the item on the Url_treeUrl
		return true;
	end;
	-- }}} item_new_clicked
	self.cl.item_new_clicked = dlffi.load(
		self.cb.item_new_clicked,
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer, }
	);
	UrlPop_new:connect('activate', self.cl.item_new_clicked);
	return true;
end;
-- }}} Guuc:init_pop

-- {{{ Guuc:align_hpaned() -- resize Url_hpanUrl
function Guuc:align_hpaned()
	local hpaned = self.builder:get_object("Url_hpanUrl");
	if not hpaned then return nil, "Url_hpanUrl not found" end;
	local wi = dlffi.dlffi_Pointer(dlffi.sizeof(gtk_t.gint), true);
	local he = dlffi.dlffi_Pointer(dlffi.sizeof(gtk_t.gint), true);
	self.win:get_size(wi, he);
	wi = gtk_t.unwrap(wi, gtk_t.gint);
	hpaned:set_position(wi / 2);
	return true;
end;
-- }}} Guuc:align_hpaned

-- {{{ Guuc:loop() -- fall into the gtk.main() loop
function Guuc:loop()
	gtk.main();
end;
-- }}} Guuc:loop

-- {{{ GroupHead

-- {{{ Guuc:init_groupHead() - initialize GroupHead part
function Guuc:init_groupHead()
	local list = self.builder:get_object("Url_comboGroupHead");
	if not list then return nil, "widget Url_comboGroupHead not found" end;
	return self:load_groups(list);
end;
-- }}} Guuc:init_groupHead

-- {{{ Guuc:load_groups(...) - load list of groups from DB
--	list - GtkComboBoxEntry
function Guuc:load_groups(list)
	local me, e = "load_groups()";
	-- initialize helpful objects
	local model;
	model, e = list:get_model();
	if not model then return self:warn{me, "get_model()", e} end;
	local sql;
	sql, e = self.sql:new(self.sql.filename);
	if not sql then return self:warn{me, "ODBC init", e} end;
	local iter;
	iter, e = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t.GtkTreeIter),
		true
	);
	if not iter then return self:warn{me, "GtkTreeIter init", e} end;
	-- fetch groups from DB
	local row, e = sql:fetch_groups();
	if not row then return self:warn{me, "fetch_groups()", e} end;
	-- add items one by one
	local gint = g.value.new(gtk.G_TYPE_INT);
	local gcharray = g.value.new(gtk.G_TYPE_STRING);
	for i = 1, #row, 1 do
		model:append(iter, dlffi.NULL);
		local v = row[i];
		g.value_set_int(gint, tonumber(v[1]));
		g.value_set_string(gcharray, tostring(v[2]));
		model:set_value(iter, 0, gint);
		model:set_value(iter, 1, gcharray);
	end;
	return true;
end;
-- }}} Guuc:load_groups

-- {{{ Guuc:select_group(...) - set selection to the specified group
--	id - ID of the group in DB
function Guuc:select_group(id)
	local me = "select_group()";
	id = tonumber(id);
	-- {{{ get widgets
	local list = self.builder:get_object("Url_comboGroupHead");
	if not list then
		return self:warn{me, "no widget Url_comboGroupHead"};
	end;
	local model = list:get_model();
	if not model then
		return self:warn{me, "no model for Url_comboGroupHead"};
	end;
	-- }}} get widgets
	local iter;
	if id then
		-- {{{ iterate through list
		iter = dlffi.dlffi_Pointer(
			dlffi.sizeof(gtk_t.GtkTreeIter),
			true
		);
		local r = model:get_iter_first(iter);
		if r ~= 1 then
			-- empty list
			return true;
		end;
		local cur;
		repeat
			local val = g.value.new();
			model:get_value(iter, 0, val);
			cur = g.value_get_int(val);
			if cur == id then break end;
		until not model:iter_next(iter);
		-- }}} iterate through list
		if cur ~= id then iter = nil end;
	end;
	-- set selection
	if not iter then
		-- not found, clear the field
		list:set_active(-1);
		local txt;
		txt, e = list:get_child();
		if not txt then
			return self:warn{me, "list:get_child()", e};
		end;
		txt:set_text("");
	else
		-- activate the item
		list:set_active_iter(iter);
	end;
	return self:display_group(id);
end;
-- }}} Guuc:select_group

-- {{{ Guuc:display_group(...) - display properties of the group
--	id	- ID of the group in DB
function Guuc:display_group(id)
	local me, e = "display_group()";
	-- {{{ find and clear table
	local tbl;
	tbl, e = self.builder:get_object("Url_tblGroupBody");
	if not tbl then return self:warn{me, "no parent table", e} end;
	local cb = function(o, ud) gtk.widget_destroy(o) end;
	local cl = dlffi.load(cb, dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer }
	);
	tbl:foreach(cl, dlffi.NULL);
	-- }}} find and clear table
	local sql, e = self.sql:new(self.sql.filename);
	if not sql then return self:err{me, "ODBC init", e} end;
	-- fetch properties from DB
	local prop, e = sql:fetch_props(id);
	if not prop then return self:err{me, "fetch_props()", e} end;
	tbl:resize(#prop, 2);
	-- iterate through found properties
	for i = 1, #prop, 1 do
		local v = prop[i];
		local txt;
		txt, e = gtk.entry_new();
		if not txt then
			return self:err{me, "gtk_entry_new()", e};
		end;
		txt:set_text(tostring(v[3]));
		local lbl;
		lbl, e = gtk.label_new(tostring(v[2]));
		if not lbl then
			return self:err{me, "gtk_entry_new()", e};
		end;
		tbl:attach(lbl._val, 0, 1, i, i + 1,
			gtk.SHRINK, gtk.SHRINK,
			0, 0
		);
		tbl:attach(txt._val, 1, 2, i, i + 1,
			gtk.FILL + gtk.EXPAND, gtk.SHRINK,
			0, 0
		);
	end;
	tbl:show_all();
	return true;
end;
-- }}} Guuc:display_group

-- }}} GroupHead

--[==[
-- {{{ Guuc object

-- {{{ Guuc properties and metatable
Guuc = {};
Guuc_mt = { __index = Guuc };
-- }}} Guuc properties and metatable

-- {{{ Guuc:new() -- constructor
function Guuc:new(sql)
	local o = {
		["sql"] = sql,
		["glade_file"] = "uuuc.glade",
		["just_added"] = false
	};
	setmetatable(o, Guuc_mt);
	o.builder = gtk.builder_new();
	local r = o.builder:add_from_file(o.glade_file, nil);
	if r < 1 then
		error('Glade file "' .. o.glade_file .. '" not found');
	end;
	o.builder:connect_signals_full(_G);
	return o;
end;
-- }}} Guuc:new()

-- {{{ Guuc:init_tree() -- initialize bindings and columns for treeUrl
function Guuc:init_tree()
	local tree = self.builder:get_object("treeUrl");
	-- {{{ item_click(tree, event)
	-- callback function on a click inside GtkTreeView
	local function item_click(tree, event)
		if event["button"].button == 1 then
			if event["type"] == gdk.GDK_2BUTTON_PRESS then
				local model, iter;
				tree:get_selection():selected_foreach(
					function(model, path, iter, data)
						local url = model:get_value(
								iter,
								1
							);
						if #url < 1 then
							return false
						end;
						io.popen(string.format(
							"xdg-open %q",
							url
						), "r");
					end, nil
				);
			end
		elseif (event["button"].button == 3) then
			return nil;
		end;
	end
	-- }}} item_click(tree, event)
	tree:connect("cursor-changed", function(o) self:show_url(o) end);
	tree:add_events(gdk.BUTTON_PRESS_MASK);
	tree:connect(
		'button_press_event',
		item_click
	);
	for k, v in ipairs {"Name", "URL"} do
		local c = gtk.tree_view_column_new_with_attributes(
			v,
			gtk.new("CellRendererText"),
			"text", k - 1,
			gnome.NIL
		);
		c:set_resizable(true);
		tree:append_column(c);
	end;
	-- drag'n'drop implementation
	tree:get_model():connect("row-deleted",
		function (model, path, data)
			if self.updating then return end;
			local parent = gtk.new("TreeIter");
			path:up();
			if model:get_iter(parent, path) then
				self.row_deleted =
					model:get_value(parent, 2);
			else
				self.row_deleted = 0;
			end;
			if self.row_changed then self:move_url() end;
		end
	);
	tree:get_model():connect("row-changed",
		function (model, path, iter, data)
			if self.updating then return end;
			self.row_changed = {
				id = model:get_value(iter, 2)
			};
			path:up();
			if model:get_iter(iter, path) then
				self.row_changed.parent =
					model:get_value(iter, 2);
			else
				self.row_changed.parent = 0;
			end;
			if self.row_deleted then self:move_url() end;
		end
	);
end;
-- }}} Guuc:init_tree()

-- {{{ Guuc:update_tree() -- refresh treeUrl content
function Guuc:update_tree()
	local tree = self.builder:get_object("treeUrl");
	local model = tree:get_model();
	local sel = tree:get_selection();
	-- {{{ remember selection
	local id_url = gtk.new("TreeIter");
	local id_g = nil;
	sel:get_selected(model, id_url);
	if model:get_value(id_url, 1, nil) ~= "" then
		id_url = model:get_value(id_url, 2, nil);
	else
		id_g = model:get_value(id_url, 2, nil);
		id_url = nil;
	end;
	-- }}} remember selection
	local path = nil;
	-- amend orphaned elements
	self.sql:query('UPDATE `urls` ' ..
		' SET `group` = (' ..
			'SELECT ' ..
				'COALESCE(`b`.`id`,0) ' ..
				'FROM `urls` AS `a` ' ..
				'LEFT JOIN `urls` AS `b` ' ..
					'ON `a`.`group` = `b`.`id` ' ..
				'WHERE `a`.`id` = `urls`.`id`' ..
		') ' ..
		'WHERE `group` > 0');
	-- {{{ deep_iter(id, model, iter)
	-- add items from group specified by `id` to GtkTreeModel
	-- under iteration specified by `iter`
	-- and iterate recursively thru subgroups
	local function deep_iter(id, model, iter)
		local s_url = 'SELECT ' ..
			'`urls`.`id`,' ..
			'`urls`.`scheme`,' ..
			'`urls`.`delim`,' ..
			'`urls`.`userinfo`,' ..
			'`urls`.`regname`,' ..
			'`urls`.`path`,' ..
			'`urls`.`query`,' ..
			'`urls`.`fragment`,' ..
			'`urls`.`descr`' ..
			' FROM `urls` ' ..
			' WHERE `urls`.`group` ' ..
				' = ' .. id;
		-- groups
		local cur = self.sql:query(s_url);
		if not cur then error(self.sql.err) end;
		local r = {};
		local subiter = gtk.new("TreeIter");
		while cur:fetch(r, "a") do
			model:append(subiter, iter);
			r["id"] = tonumber(r["id"]);
			if (r["id"] == id_url) or self.just_added then
				path = model:get_path(subiter);
			end;
			model:set(subiter,
				0, r["descr"],
				1, implode_uri(r),
				2, gnome.box(r["id"], "gint64"),
				-1
			);
			deep_iter(r["id"], model, subiter);
		end;
		cur:close();
	end;
	-- }}} deep_iter(id, model, iter)
	model:clear();
	self.updating = true;
	deep_iter(0, model, nil);
	self.updating = nil;
	tree:expand_all();
	if path ~= nil then
		sel:unselect_all();
		sel:select_path(path);
	end;
	self.just_added = false;
	self:show_url();
	return true;
end;
-- }}} Guuc:update_tree()

-- {{{ Guuc:show_url() -- show URL info in a right panel
function Guuc:show_url(btn)
	local tree = self.builder:get_object("treeUrl");
	local txtname = self.builder:get_object("txtName");
	local txturl = self.builder:get_object("txtUrl");
	-- clear fields
	txtname:set_text("");
	txturl:set_text("");
	self:flush_prop();
	-- loop thru selected items
	local sel = tree:get_selection();
	local count = sel:count_selected_rows();
	sel:selected_foreach(
		function(model, path, iter, data)
			count = count - 1;
			if count > 0 then return end;
			txtname:set_text(model:get_value(iter, 0));
			txturl:set_text(model:get_value(iter, 1));
			local s = tonumber(model:get_value(iter, 2));
			if not s then return end;
			s = "SELECT `name`, `value` FROM `groups` " ..
				" WHERE `url` = " .. s;
			local cur = self.sql:query(s);
			local stat = self.builder:get_object("statusbarMain");
			stat:pop(13);
			stat:push(
				13,
				string.format(
					"[%d] SQL:: %s",
					os.time(),
					self.sql.err
				)
			);
			if not cur then return end;
			local r = {};
			while cur:fetch(r, "a") do
				self:add_prop(r["name"], r["value"]);
			end;
		end, nil
	);
end;
-- }}} Guuc:show_url()

-- {{{ Guuc:flush_prop() -- clear the property table
function Guuc:flush_prop()
	glib.list_foreach(
		self.builder:get_object("tableProperty"):get_children(),
		function (data, udata) data:destroy() end,
		-1
	);
end;
-- }}} Guuc:flush_prop()

-- {{{ Guuc:save_url() -- saves URL info into
function Guuc:save_url(btn)
	local tree = self.builder:get_object("treeUrl");
	local count = tree:get_selection():count_selected_rows();
	local function save(model, path, iter, data)
		count = count - 1;
		if count > 0 then return end;
		local prop = {};
		glib.list_foreach(
			self.builder:get_object(
				"tableProperty"
			):get_children(),
			function (data, udata)
				local row = data:get_data("tbl_row").value;
				local col = data:get_data("tbl_col").value;
				if not prop[row] then prop[row] = {} end;
				local t = data:get_type();
				if t == gtk.entry_get_type() then
					prop[row][col] = data:get_text();
				elseif t == gtk.text_view_get_type() then
					local s = gtk.new("TextIter");
					local e = gtk.new("TextIter");
					local tb = data:get_buffer();
					tb:get_bounds(s, e);
					prop[row][col] =
						tb:get_text(s, e, false);
				end;
			end,
			-1
		);
		self.sql:update_url(
			model:get_value(iter, 2),
			self.builder:get_object("txtName"):get_text(),
			self.builder:get_object("txtUrl"):get_text(),
			nil,
			prop
		);
		local stat = self.builder:get_object("statusbarMain");
		stat:pop(13);
		stat:push(
			13,
			string.format(
				"[%d] SQL:: %s",
				os.time(),
				self.sql.err
			)
		);
		self:update_tree();
	end;
	tree:get_selection():selected_foreach(save, nil);
end;
-- }}} Guuc:save_url()

-- {{{ Guuc:add_url() -- add a new empty URL
function Guuc:add_url()
	self.sql.descr = "";
	self.sql.url = "http://";
	self.sql.group = "";
	self.just_added = true;
	self.sql:add();
	local stat = self.builder:get_object("statusbarMain");
	stat:pop(13);
	stat:push(
		13,
		string.format(
			"[%d] SQL:: %s",
			os.time(),
			self.sql.err
		)
	);
	self:update_tree();
end;
-- }}} Guuc:add_url

-- {{{ Guuc:del_url() -- delete selected URL
function Guuc:del_url()
	local tree = self.builder:get_object("treeUrl");
	local count = tree:get_selection():count_selected_rows();
	local function delete(model, path, iter, data)
		count = count - 1;
		if count > 0 then return end;
		self.sql:query(string.format(
			'DELETE FROM `groups` WHERE `url` = %d',
			model:get_value(iter, 2)
		));
		self.sql:query(string.format(
			'DELETE FROM `urls` WHERE `id` = %d',
			model:get_value(iter, 2)
		));
	end;
	tree:get_selection():selected_foreach(delete, nil);
	local stat = self.builder:get_object("statusbarMain");
	stat:pop(13);
	if self.sql.err then
		stat:push(
			13,
			string.format(
				"[%d] SQL:: %s",
				os.time(),
				self.sql.err
			)
		);
	end;
	self:update_tree();
end;
-- }}} Guuc:del_url

-- {{{ Guuc:add_prop() -- add a new property
function Guuc:add_prop(name, value)
	local tbl = self.builder:get_object("tableProperty");
	local rows = glib.list_length(tbl:get_children())/2;
	tbl:resize(rows + 1, 2);
	local prop = {
		{name, gtk.GTK_FILL, gtk.gtk_entry_new},
		{value, gtk.GTK_FILL + gtk.GTK_EXPAND,
			function ()
				return gtk.text_view_new_with_buffer(
					gtk.text_buffer_new()
				)
			end
		}
	};
	local elements = {};
	local view = self.builder:get_object("scrwinProperty");
	for k, v in ipairs(prop) do
	local txt = v[3]();
	table.insert(elements, txt);
	local t = txt:get_type();
	if t == gtk.entry_get_type() then
		txt:set_text(v[1]);
	elseif t == gtk.text_view_get_type() then
		txt:get_buffer():set_text(v[1], -1);
	end;
	tbl:attach(txt,
		k - 1, k,
		rows, rows + 1,
		v[2], gtk.GTK_FILL,
		0, 0);
	txt:set_data("tbl_row", rows + 1);
	txt:set_data("tbl_col", k);
	txt:show();
	end;
	return elements;
end;
-- }}} Guuc:add_prop()

-- {{{ Guuc:move_url() -- change parent element of an item
function Guuc:move_url()
	self.sql:query('UPDATE `urls` ' ..
		' SET `group` = ' ..
			self.sql:escape(self.row_changed.parent) ..
		' WHERE `id` = ' ..
			self.sql:escape(self.row_changed.id)
		);
	self.row_deleted = nil;
	self.row_changed = nil;
end;
-- }}} Guuc:move_url()

-- {{{ Guuc:main()
function Guuc:main()
	local bld = self.builder;
	-- winMain
	local winMain = bld:get_object("winMain");
	winMain:connect("destroy", gtk.main_quit);
	-- menuMainQuit
	local menuQuit = bld:get_object("menuMainQuit");
	menuQuit:connect("activate", gtk.main_quit);
	-- toolbar
	bld:get_object("toolMainRemove"):connect(
		"clicked",
		function(btn) self:del_url() end
	);
	bld:get_object("toolMainRefresh"):connect(
		"clicked",
		function(btn) self:update_tree() end
	);
	bld:get_object("toolMainAdd"):connect(
		"clicked",
		function(btn) self:add_url() end
	);
	-- {{{ properties toolbar
	--[[
	bld:get_object("toolPropertyAdd"):connect(
		"clicked",
		function(btn)
			local e = self:add_prop("Attribute", "Value");
			if e[1] then e[1]:grab_focus() end;
		end
	);
	--]]
	-- }}} properties toolbar
	-- {{{ control buttons
	bld:get_object("btnRestore"):connect(
		"pressed",
		function(btn) self:show_url(btn) end
	);
	bld:get_object("btnSave"):connect(
		"pressed",
		function(btn) self:save_url(btn) end
	);
	-- }}} control buttons
	-- {{{ file chooser dialog
	local winFile = bld:get_object("winFile");
	winFile:connect("delete-event", gtk.widget_hide_on_delete);
	bld:get_object("btnFile"):connect(
		"pressed",
		function (btn) winFile:show() end
	);
	bld:get_object("btnFileCancel"):connect(
		"pressed",
		function (btn) winFile:hide() end
	);
	bld:get_object("btnFileOk"):connect(
		"pressed",
		function (btn)
			bld:get_object("txtUrl"):set_text(
				winFile:get_uri()
			);
			winFile:hide();
		end
	);
	-- }}} file chooser dialog
	-- display DB content
	self:update_tree();
	self:init_tree();
	local grp, e = Groups:new(self);
	if not grp then
		return nil, "Failed to initialize `Groups`" .. e;
	end;
	--grp:show();
	gtk.main();
	return true;
end;
-- }}} Guuc:main()

-- }}} Guuc object
--]==]

return {
	["Guuc"] = Guuc,
};

-- vim: set foldmethod=marker:
