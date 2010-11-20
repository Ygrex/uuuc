local gtk = require "gtk";
assert(type(gtk) == "table", "Error loading GTK module");

local dlffi = gtk.dlffi;
local gtk_t = gtk.typedef;
local g = gtk.g;
local gdk = gtk.gdk;
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

-- {{{ fill_model(...) - fill GtkTreeModel with given data
--	model	- model or list view with model
--	data	- data table
--	header	- two keys to read from data or {1, 2} by default
local function fill_model(model, data, header)
	if not data then return end;
	local me = "fill_view()";
	if not header then header = {1, 2} end;
	if not model then self:warn{me, "invalid GtkTreeModel"} end;
	local r;
	local e;
	-- if model given or list view
	r, e = g.type_check_instance_is_a(
		(type(model) == "table") and model._val or model,
		gtk.tree_model_get_type()
	);
	if e then
		self:warn{me, "g_type_check_instance_is_a()", e};
	end;
	if r == 0 then
		-- list view given; retreive attached model
		model, e = model:get_model();
		if not model then self:warn{me, "get_model()", e} end;
	end;
	-- initialize iterator
	local iter;
	iter, e = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t.GtkTreeIter),
		true
	);
	if not iter then return self:warn{me, "GtkTreeIter init", e} end;
	-- initialize GValue's
	local gint = g.value.new(gtk.G_TYPE_INT);
	local gcharray = g.value.new(gtk.G_TYPE_STRING);
	-- traverse data
	for i = 1, #data, 1 do
		model:append(iter, dlffi.NULL);
		local v = data[i];
		g.value_set_int(gint, tonumber(v[header[1]]));
		g.value_set_string(gcharray, tostring(v[header[2]]));
		model:set_value(iter, 0, gint);
		model:set_value(iter, 1, gcharray);
	end;
	return true;
end;
-- }}} fill_model()

-- {{{ Guuc:new() -- constructor
function Guuc:new(sql)
	local me = "Guuc:new()";
	if not sql then
		return nil, "Sqlite3 connector must be specified";
	end;
	local o = {
		["sql"] = sql,			-- Sqlite3 connector
		["glade_file"] = GLADE_FILE,	-- glade file to load
		["builder"] = "",		-- GTK builder
		["win"] = "",			-- Url_win
		["list"] = "",			-- Url_treeUrl
		["cl"] = {},			-- storage of closures to cb
	};
	if not o["glade_file"] then
		return nil, "GLADE_FILE is not specified";
	end;
	setmetatable(o, Guuc_mt);
	local e;
	o.gtk_t, e = dlffi.Dlffi_t:new();
	if not o.gtk_t then return self:warn{me, "Dlffi_t:new()", e} end;
	o.gtk_t["ListStore"] = {gtk_t.GType, gtk_t.GType, gtk_t.GType};
	if not o.gtk_t["ListStore"] then
		return self:warn{me, "Dlffi_t:new()", "ListStore"};
	end;
	o.builder = gtk.builder_new();
	if not o.builder then
		return nil, "GtkBuilder initialization failure";
	end;
	local r = o.builder:add_from_file(o.glade_file, dlffi.NULL);
	if (not tonumber(r)) or (r < 1) then
		return nil, "gtk_builder_add_from_file() failed";
	end;
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
	-- work with Url_treeUrl
	local list = self.builder:get_object("Url_treeUrl");
	if not list then return nil, "widget Url_treeUrl not found" end;
	self.list = list;
	r, e = self:init_tree();
	if not r then return nil, e end;
	-- load GroupHead
	r, e = self:init_groupHead();
	if not r then return nil, e end;
	-- init Url_toolUrl
	r, e = self:init_Url_toolUrl();
	if not r then return nil, e end;
	-- finalize
	win:show_all();
	-- check the position of Url_hpanUrl
	--self:align_hpaned();
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
	show_popup = function (tree, event)
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
		show_popup,
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
		local val;
		val, e = self:get_active_uri(sel);
		if not val then
			return self:err{me, e};
		end;
		local uri;
		uri, e = sql:fetch_uri(val);
		if not uri then return self:err {me, "sql:fetch_uri()", e} end;
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
		name:set_text(tostring(uri["uri"]));
		misc:set_text(uri["misc"], #(uri["misc"]));
		-- activate appropriate group
		self:select_group(uri["group"], uri["id"]);
		return true;
	end;
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
	local iter = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t.GtkTreeIter),
		true
	);
	local r = sel:get_selected(dlffi.NULL, iter);
	if not r then return nil end;
	if r == 0 then return nil end;
	return iter;
end;
-- }}} Guuc:get_selected

-- {{{ Guuc:get_active_uri(...) - return ID of the active URI
--	sel - GtkTreeSelection to look at;
--		self.list:get_selection() by default
function Guuc:get_active_uri(sel)
	local me, e = "get_active_uri()";
	if not sel then
		-- GtkTreeSelection
		sel = self.list:get_selection();
		if not sel then return self:warn{me, "get_selection()"} end;
	end;
	local iter = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t.GtkTreeIter),
		true
	);
	-- GtkTreeModel, GtkTreeIter
	local model = dlffi.dlffi_Pointer();
	local r;
	r, e = sel:get_selected(dlffi.dlffi_Pointer(model), iter);
	if (not r) or (r == 0) then
		return self:warn{me, "get_selected()", r, e};
	end;
	model, e = gtk_t(model);
	if not model then
		return self:warn {
			me,
			"sel:get_selected(): no model returned",
			e
		};
	end;
	local val;
	val, e = g.value.new();
	if not val then return self:warn{me, "value_new()"} end;
	model:get_value(iter, 0, val);
	return g.value_get_int(val);
end;
-- }}} Guuc:get_active_uri()

-- {{{ Guuc:init_pop() -- initialize popup menu for Url_treeUrl
function Guuc:init_pop()
	local me = "init_pop()";
	local UrlPop_new = self.builder:get_object("UrlPop_new");
	if not UrlPop_new then
		return self:warn{me, "menu item UrlPop_new not found"};
	end;
	-- {{{ item_new_clicked -- create new URI
	item_new_clicked = function(btn)
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
		item_new_clicked,
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer, }
	);
	UrlPop_new:connect('activate', self.cl.item_new_clicked);
	return true;
end;
-- }}} Guuc:init_pop

--[[
-- {{{ Guuc:align_hpaned() -- resize Url_hpanUrl
function Guuc:align_hpaned()
	local hpaned = self.builder:get_object("Url_hpanUrl");
	if not hpaned then return nil, "Url_hpanUrl not found" end;
	local wi = dlffi.dlffi_Pointer(dlffi.sizeof(gtk_t.gint), true);
	local he = dlffi.dlffi_Pointer(dlffi.sizeof(gtk_t.gint), true);
	self.win:get_size(wi, he);
	wi = gtk_t.unwrap(wi, gtk_t.gint);
	he = gtk_t.unwrap(he, gtk_t.gint);
	print(wi, he);
	hpaned:set_position(wi / 2);
	return true;
end;
-- }}} Guuc:align_hpaned
--]]

-- {{{ Guuc:loop() -- fall into the gtk.main() loop
function Guuc:loop()
	gtk.main();
end;
-- }}} Guuc:loop

-- {{{ GroupHead

-- {{{ read_combo(...) - get 1st, 2nd column values and active text
--	obj - GtkComboBoxEntry
local function read_combo(obj)
	if not obj then
		return nil, "invalid GtkComboBoxEntry";
	end;
	local txt = obj:get_active_text();
	if not txt then return nil, "get_active_text()" end;
	-- returned string must be freed
	txt = dlffi.dlffi_Pointer(txt, true):tostring();
	local model, e = obj:get_model();
	if not model then
		return nil, "get_model(): " .. tostring(e);
	end;
	local iter = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t["GtkTreeIter"]),
		true
	);
	local r = obj:get_active_iter(iter);
	if not r then return nil, "get_active_iter()" end;
	if r == 0 then
		-- nothing selected
		return -1, "", txt;
	end;
	local fir = g.value.new();
	local sec = g.value.new();
	model:get_value(iter, 0, fir);
	model:get_value(iter, 1, sec);
	fir = g.value_get_int(fir);
	sec = dlffi.dlffi_Pointer(
		g.value_get_string(sec),
		false
	):tostring();
	return fir, sec, txt;
end;
-- }}} read_combo()

-- {{{ read_textview(...) - read text from GtkTextView
--	widget	- GtkTextView;
--		Url_txtMisc by default
--	builder	- required if widget is not specified
function read_textview(widget, builder)
	local e;
	if not widget then
		widget, e = builder:get_object("Url_txtMisc");
		if not widget then
			return nil, "get_object(): " .. tostring(e);
		end;
	end;
	widget, e = widget:get_buffer();
	if not widget then
		return nil, "get_buffer(): " .. tostring(e);
	end;
	local ibeg = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t["GtkTextIter"]),
		true
	);
	if not ibeg then return nil, "iter_begin" end;
	local iend = dlffi.dlffi_Pointer(
		dlffi.sizeof(gtk_t["GtkTextIter"]),
		true
	);
	if not ibeg then return nil, "iter_end" end;
	_, e = widget:get_bounds(ibeg, iend);
	if e then return nil, "get_bounds(): " .. tostring(e) end;
	return dlffi.dlffi_Pointer(
		widget:get_text(ibeg, iend, 1),
		true
	):tostring();
end;
-- }}} read_textview()

-- {{{ read_textentry(...) - read text from GtkEntry
function read_textentry(widget, builder)
	local e;
	if not widget then
		widget, e = builder:get_object("Url_txtName");
		if not widget then
			return nil, "get_object(): " .. tostring(e);
		end;
	end;
	return dlffi.dlffi_Pointer(widget:get_text()):tostring();
end;
-- }}} read_textentry()

-- {{{ Guuc:init_groupHead() - initialize GroupHead part
function Guuc:init_groupHead()
	local list = self.builder:get_object("Url_comboGroupHead");
	if not list then return nil, "widget Url_comboGroupHead not found" end;
	local changed = function(obj, ud)
		local me = "changed_Url_comboGroupHead()";
		local uri, e = self:get_active_uri();
		if not uri then self:err{me, e} end;
		local grp;
		grp, e = read_combo(list);
		if not grp then self:err{me, "read_combo()", e} end;
		self:display_group(grp, uri);
	end;
	changed, e = dlffi.load(changed,
		dlffi.ffi_type_void,
		{dlffi.ffi_type_pointer, dlffi.ffi_type_pointer}
	);
	if not changed then return nil, "Url_comboGroupHead closure" end;
	list:connect("changed", changed);
	self.cl["changed_Url_comboGroupHead"] = changed;
	return self:load_groups(list);
end;
-- }}} Guuc:init_groupHead

-- {{{ Guuc:load_groups(...) - load list of groups from DB
--	list - GtkComboBoxEntry
function Guuc:load_groups(list)
	local me, e = "load_groups()";
	-- fetch groups from DB
	local sql;
	sql, e = self.sql:new(self.sql.filename);
	if not sql then return self:warn{me, "ODBC init", e} end;
	local row;
	row, e = sql:fetch_groups();
	if not row then return self:warn{me, "fetch_groups()", e} end;
	return fill_model(list, row);
end;
-- }}} Guuc:load_groups

-- {{{ Guuc:select_group(...) - set selection to the specified group
--	id - ID of the group in DB
--	uri - URI ID
function Guuc:select_group(id, uri)
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
	return self:display_group(id, uri);
end;
-- }}} Guuc:select_group

-- {{{ get_value(...) - read property's value from DB
--	rec - DB record of the URI's property
local function get_value(rec)
	if rec["value"] and not (rec["value"] == dlffi.NULL) then
		return rec["value"]
	elseif rec["default"] and not (rec["default"] == dlffi.NULL) then
		return rec["default"]
	end;
	return "";
end;
-- }}} get_value()

-- {{{ get_widget_value(...) - read property's value from the widget
--	widget - widget
local function get_widget_value(widget)
	local me, e = "get_widget_value()";
	widget, e = gtk_t(widget);
	if not widget then return self:warn{me, gtk_t, e} end;
	-- {{{ GtkEntry
	if widget.get_text then
		widget = widget:get_text();
		return dlffi.dlffi_Pointer(widget):tostring();
	end;
	-- }}} GtkEntry
	-- {{{ GtkTextView
	if widget.get_buffer then
		widget, e = widget:get_buffer();
		if not widget then
			return self:warn{me, "get_buffer()", e};
		end;
		local ibeg = dlffi.dlffi_Pointer(
			dlffi.sizeof(gtk_t["GtkTextIter"]),
			true
		);
		local iend = dlffi.dlffi_Pointer(
			dlffi.sizeof(gtk_t["GtkTextIter"]),
			true
		);
		_, e = widget:get_bounds(ibeg, iend);
		if e then return self:warn{me, "get_bounds()", e} end;
		widget = widget:get_text(ibeg, iend, true);
		widget = dlffi.dlffi_Pointer(widget, true):tostring();
		return widget;
	end;
	-- }}} GtkTextView
	-- {{{ GtkComboBox
	if widget.get_model and widget.get_active_iter then
		local iter = dlffi.dlffi_Pointer(
			dlffi.sizeof(gtk_t["GtkTreeIter"]),
			true
		);
		e = widget:get_active_iter(iter);
		if e ~= 1 then
			-- new item selected
			return self:warn{me, "new item selected"};
		end;
		if type(iter) == "table" then iter = iter._val end;
		widget, e = widget:get_model();
		if not widget then return self:warn{me, "get_model()", e} end;
		local val = g.value.new();
		widget:get_value(iter, 0, val);
		return g.value_get_int(val);
	end;
	-- }}} GtkComboBox
	return self:warn{me, "unknown widget type"};
end;
-- }}} get_widget_value()

-- {{{ Guuc:make_list(...) - create GtkComboBoxEntry for property
function Guuc:make_list(rec, data)
	local me, e = "make_list()";
	-- {{{ compose array of column types
	local str = self.gtk_t["ListStore"];
	local cols;
	cols, e = dlffi.dlffi_Pointer(dlffi.sizeof(str), true);
	if not cols then return self:warn{me, "dlffi_Pointer()", e} end;
	e = dlffi.type_element(cols, str, 1, gtk.G_TYPE_INT);
	if not e then return self:warn{me, "1st column"} end;
	e = dlffi.type_element(cols, str, 2, gtk.G_TYPE_STRING);
	if not e then return self:warn{me, "2nd column"} end;
	-- }}} compose array of column types
	-- {{{ create GtkComboBoxEntry
	local model;
	model, e = gtk.list_store_newv(2, cols);
	if not model then return self:warn{me, "gtk_list_store_newv()", e} end;
	local lst;
	lst, e = gtk.combo_box_entry_new_with_model(model._val, 1);
	if not lst then
		model:destroy();
		return self:warn{
			me,
			"gtk_combo_box_entry_new_with_model()",
			e
		}
	end;
	local destroy = function(...)
		lst:destroy();
		model:destroy();
		return self:warn(...);
	end;
	-- }}} create GtkComboBoxEntry
	-- {{{ fill model with data
	_, e = fill_model(model, data);
	if e then return destroy{me, e} end;
	-- }}} fill model with data
	-- {{{ set value
	local val = tonumber(get_value(rec));
	if val then
		-- find index by ID
		for i = 1, #data, 1 do
			if data[i][1] == val then
				e = i;
				break;
			end;
		end;
		if e then val = e - 1 else val = nil end;
	end;
	if not val then
		-- no value
		lst:set_active(-1);
		local txt;
		txt, e = lst:get_child();
		if not txt then return destroy{me, "get_child()", e} end;
		txt:set_text("");
	else
		lst:set_active(val);
	end;
	-- }}} set value
	return lst;
end;
-- }}} Guuc:make_list()

-- {{{ Guuc:make_text(...) - create a text field for to display property
--	rec - record from table returned by sql:fetch_props()
--	return GtkEntry
function Guuc:make_text(rec)
	local me, e = "make_text()";
	local txt;
	txt, e = gtk.text_buffer_new(dlffi.NULL);
	if (not txt) or (txt == dlffi.NULL) then
		return self:warn{me, "text_buffer_new()", e};
	end;
	local view;
	view, e = gtk.text_view_new_with_buffer(txt._val);
	if (not view) or (view == dlffi.NULL) then
		return self:warn{me, "text_view_new()", e};
	end;
	view:set_wrap_mode(gtk.WRAP_WORD_CHAR);
	txt:set_text(tostring(get_value(rec)), -1);
	return view;
end;
-- }}} Guuc:make_text()

-- {{{ Guuc:make_string(...) - create a text field for to display property
--	rec - record from table returned by sql:fetch_props()
--	return GtkEntry
function Guuc:make_string(rec)
	local me, e = "make_string()";
	local txt;
	txt, e = gtk.entry_new();
	if not txt then return self:warn{me, "gtk_entry_new()", e} end;
	txt:set_text(tostring(get_value(rec)));
	return txt;
end;
-- }}} Guuc:make_string()

-- {{{ Guuc:display_group(...) - display properties of the group
--	group	- ID of the group in DB
--	uri	- ID of URI in DB
function Guuc:display_group(group, uri)
	local me, e = "display_group()";
	-- {{{ find and clear table
	local tbl;
	tbl, e = self.builder:get_object("Url_tblGroupBody");
	if not tbl then return self:warn{me, "no parent table", e} end;
	-- {{{ destroy child widget
	local cb = function(o, ud)
		local gid = g.object_get_data(o, "id");
		if gid and (gid ~= dlffi.NULL) then
			-- unset and free memory
			g.value_unset(dlffi.dlffi_Pointer(gid, true));
		end;
		gtk.widget_destroy(o);
	end;
	-- }}} destroy child widget
	local cl = dlffi.load(cb, dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer }
	);
	tbl:foreach(cl, dlffi.NULL);
	-- }}} find and clear table
	local sql;
	sql, e = self.sql:new(self.sql.filename);
	if not sql then return self:err{me, "ODBC init", e} end;
	-- fetch properties from DB
	local prop;
	prop, e = sql:fetch_props(group, uri);
	if not prop then return self:err{me, "fetch_props()", e} end;
	tbl:resize(#prop, 2);
	-- iterate through found properties
	for i = 1, #prop, 1 do
		local v = prop[i];
		local data;
		if v["type"] == "list" then
			-- read items
			data, e = sql:fetch_items(v["id"]);
		end;
		local val;
		if v["type"] == "list" then
			val, e = self:make_list(v, data);
		else
			if v["type"] == "text" then
				val, e = self:make_text(v);
			else
				val, e = self:make_string(v);
			end;
		end;
		if not val then return self:err{me, e} end;
		-- create GValue to store property ID
		local gid = g.value.new(false);
		if gid then
			g.value_init(gid, gtk.G_TYPE_INT);
			g.value_set_int(gid, tonumber(v["id"]));
			g.object_set_data(
				(type(val) == "table") and val._val or val,
				"id",
				gid
			);
		end;
		local lbl;
		lbl, e = gtk.label_new(tostring(v["name"]));
		if not lbl then
			return self:err{me, "gtk_entry_new()", e};
		end;
		tbl:attach(lbl._val, 0, 1, i, i + 1,
			0, 0,
			0, 0
		);
		tbl:attach(val._val, 1, 2, i, i + 1,
			gtk.FILL + gtk.EXPAND, gtk.SHRINK,
			0, 0
		);
	end;
	tbl:show_all();
	return true;
end;
-- }}} Guuc:display_group

-- }}} GroupHead

-- {{{ Url_toolUrl

-- {{{ Guuc:Url_toolName_Local() - "clicked" callback
function Guuc:Url_toolName_Local(btn, ud)
	local me, e = "Url_toolUrl_Open()";
	local path;
	local dialog = self.win;
	if type(dialog) == "table" then dialog = dialog._val end;
	dialog, e = gtk.file_chooser_dialog_new(
		"Choose file",
		dialog,
		gtk.FILE_CHOOSER_ACTION_OPEN,
		gtk.STOCK_CANCEL,
		gtk.RESPONSE_CANCEL,
		gtk.STOCK_OPEN,
		gtk.RESPONSE_ACCEPT,
		dlffi.NULL
	);
	if e then return self:err{me, "dialog_new()", e} end;
	path, e = gtk.dialog_run(dialog._val);
	if e then return self:err{me, "dialog_run()", e} end;
	if path == gtk.RESPONSE_ACCEPT then repeat
		path, e = dialog:get_uri();
		if e then
			self:err{me, "get_uri()", e};
			break;
		end;
		self.builder:get_object("Url_txtName"):set_text(path);
		g.free(path);
	until true end;
	dialog:destroy();
end;
-- }}} Guuc:Url_toolName_Local()

-- {{{ Guuc:Url_toolUrl_Open() - "clicked" callback
function Guuc:Url_toolUrl_Open(btn, ud)
	local me, e = "Url_toolUrl_Open()";
	-- {{{ read URL
	local path;
	path, e = read_textentry(nil, self.builder);
	if not path then
		return self:err{me, "read_textentry()", e};
	end;
	-- }}} read URL
	-- {{{ argv
	local str;
	str, e = dlffi.Dlffi_t:new("argv", {
		dlffi.ffi_type_pointer,	-- argv[0]
		dlffi.ffi_type_pointer,	-- argv[1]
		dlffi.ffi_type_pointer,	-- argv[2]
	});
	if (not str) or (not str["argv"]) then
		return self:err{me, "Dlffi_t:new()", e};
	end;
	local argv = dlffi.dlffi_Pointer(
		dlffi.sizeof(str["argv"]),
		true
	);
	if not argv then return self:err{me, "malloc()"} end;
	-- set argv[0]
	dlffi.type_element(argv, str["argv"], 1, "xdg-open");
	-- string duplicate must be GCed later
	local argv1 = dlffi.dlffi_Pointer(
		dlffi.type_element(argv, str["argv"], 1),
		true
	);
	-- set argv[1]
	dlffi.type_element(argv, str["argv"], 2, path);
	-- string duplicate must be GCed later
	local argv2 = dlffi.dlffi_Pointer(
		dlffi.type_element(argv, str["argv"], 2),
		true
	);
	-- set argv[2]
	dlffi.type_element(argv, str["argv"], 3, dlffi.NULL);
	-- }}} argv
	-- {{{ get default display
	local r;
	r, e = gdk.display_get_default();
	if (not r) or (r == dlffi.NULL) then
		return self:err{
			me,
			"gdk_display_get_default()",
			e
		};
	end;
	r, e = gdk.display_get_default_screen(r);
	if (not r) or (r == dlffi.NULL) then
		return self:err{
			me,
			"gdk_display_get_default_screen()",
			e
		};
	end;
	-- }}} get default display
	r, e = gdk.spawn_on_screen_with_pipes(
		r,		-- screen
		dlffi.NULL,	-- working_directory
		argv,		-- argv
		dlffi.NULL,	-- engvp
		gtk.G_SPAWN_SEARCH_PATH +
		0
		,	-- flags
		dlffi.NULL,	-- child_setup
		dlffi.NULL,	-- user_data
		dlffi.NULL,	-- child_pid
		dlffi.NULL,	-- stdin
		dlffi.NULL,	-- stdout
		dlffi.NULL,	-- stderr
		dlffi.NULL	-- error
	);
	if (not r) or (r == 0) then
		return self:err{
			me,
			"gdk_spawn_on_screen_with_pipes()",
			e
		};
	end;
end;
-- }}} Guuc:Url_toolUrl_Open()

-- {{{ Guuc:Url_toolUrl_Save() - "clicked" callback
function Guuc:Url_toolUrl_Save(btn, ud)
	local me, e = "Url_toolUrl_Save()";
	-- get selected item
	local url = self.list;
	local uri;
	uri, e = self:get_selected(url);
	if not uri then return self:err{me, "get_selected()", e} end;
	local urm;
	urm, e = url:get_model();
	if not urm then return self:err{me, "get_model()", e} end;
	-- {{{ find URI ID
	local id = g.value.new();
	urm:get_value(type(uri) == "table" and uri._val or uri, 0, id);
	id = g.value_get_int(id);
	-- }}} find URI ID
	-- {{{ gather URI info
	-- {{{ read URI
	local txturi, txtmisc;
	txturi, e = read_textentry(nil, self.builder);
	if e then return self:err{me, "read_textentry()", e} end;
	txtmisc, e = read_textview(nil, self.builder);
	if e then return self:err{me, "read_textview()", e} end;
	-- }}} read URI
	-- {{{ read group
	local grp_id, grp_txt, txtgrp = read_combo(
		self.builder:get_object("Url_comboGroupHead")
	);
	if not grp_id then
		return self:err{me, "get_object", grp_txt};
	end;
	if grp_txt ~= txtgrp then
		-- new group
		return self:err{
			me,
			"group creating not implemented"
		};
	end;
	-- }}} read group
	-- {{{ write URI
	if grp_id < 0 then grp_id = nil end;
	local sql;
	sql, e = self.sql:new(self.sql.filename);
	if not sql then return self:warn{me, "ODBC init", e} end;
	_, e = sql:write_uri(id, txturi, txtmisc, grp_id);
	if e then return self:err{me, "write_uri()", e} end;
	-- }}} write URI
	-- {{{ update URI name in GtkTreeView
	local val = g.value.new(gtk.G_TYPE_STRING);
	g.value_set_string(val, txtmisc);
	urm:set_value(uri, 1, val);
	-- }}} update URI name in GtkTreeView
	-- {{{ read/write properties
	local tbl;
	tbl, e = self.builder:get_object("Url_tblGroupBody");
	if not tbl then
		return self:err{me, "Url_tblGroupBody", e};
	end;
	local get_child = function(o, ud)
		local me, e = "get_child()";
		-- get property ID
		local prop = g.object_get_data(o, "id");
		if prop and (prop ~= dlffi.NULL) then
			-- read property ID
			prop = g.value_get_int(prop);
		end;
		-- get value
		local val;
		val, e = get_widget_value(o);
		if not val then return self:err{me, e} end;
		-- write value
		_, e = sql:write_value(id, prop, val);
		if e then return self:err{me, e} end;
	end;
	local cl;
	cl, e = dlffi.load(
		get_child,
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer }
	);
	if not cl then return self:err{me, "closure", e} end;
	tbl:foreach(cl, dlffi.NULL);
	-- }}} read/write properties
	-- }}} gather URI info
end;
-- }}} Guuc:Url_toolUrl_Save()

-- {{{ Guuc:init_Url_toolUrl()
function Guuc:init_Url_toolUrl()
	local me, e = "init_Url_toolUrl()";
	-- buttons to attach "connect" handler
	local btn = {
		"Url_toolUrl_Save",
		"Url_toolUrl_Open",
		"Url_toolName_Local",
	};
	for i = 1, #btn, 1 do
		local cur;
		cur, e = self.builder:get_object(btn[i]);
		local name = btn[i];
		if not cur then
			return self:warn{me, "get_object()", name, e};
		end;
		local closure = function (obj, ud)
			self[name](self, obj, ud);
		end;
		closure = dlffi.load(closure,
			dlffi.ffi_type_pointer,
			{
				dlffi.ffi_type_pointer,
				dlffi.ffi_type_pointer,
			}
		);
		-- prevent closure from being GC'ed
		self.cl[name] = closure;
		_, e = cur:connect("clicked", closure);
		if e then
			return self:warn{me, "connect()", name, e};
		end;
	end;
	return true;
end;
-- }}} Guuc:init_Url_toolUrl()

-- }}} Url_toolUrl

return {
	["Guuc"] = Guuc,
};

-- vim: set foldmethod=marker:
