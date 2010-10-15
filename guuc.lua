require "gtk";

local Guuc = { _type = "object" };
local Guuc_mt = { __index = Guuc };

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
	};
	if not o["glade_file"] then
		return nil, "GLADE_FILE is not specified";
	end;
	setmetatable(o, Guuc_mt);
	o.builder = gtk.builder_new();
	local r = o.builder:add_from_file(o.glade_file, nil);
	if r < 1 then
		return nil, "gtk_builder_add_from_file() failed";
	end;
	o.builder:connect_signals_full();
	local r, e = o:init();
	if not r then return nil, e end;
	return o;
end;
-- }}} Guuc:new()

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
	self:init_tree();
	-- finalize
	win:show_all();
	return true;
end;
-- }}} Guuc:init

-- {{{ Guuc:attach_pop() -- setup popup menu for Url_treeUrl
function Guuc:attach_pop()
	local tree = self.builder:get_object("Url_treeUrl");
	if not tree then return nil, "widget Url_treeUrl not found" end;
	local popup = self.builder:get_object("UrlPop_win");
	if not popup then return nil, "widget UrlPop_win not found" end;
	self:init_pop();
	-- popup handler
	local function show_popup(tree, event)
		-- treat the right button only
		if event["button"].button ~= 3 then return false end;
		gtk.menu_popup(
			popup,			-- menu
			nil,		-- parent_menu_shell
			nil,		-- parent_menu_item
			nil,		-- func
			nil,		-- data
			event["button"].button,	-- button
			event["button"].time
		);
		return true;
	end;
	-- listen to the button press event
	tree:connect('button_press_event', show_popup);
	return true;
end;
-- }}} Guuc:attach_pop

-- {{{ Guuc:init_tree() -- initialize Url_treeUrl
function Guuc:init_tree()
	local list = self.list;
	if not list then return nil, "self.list is undefined" end;
	-- {{{ init columns
	local col = gtk.tree_view_column_new_with_attributes(
		"URI",
		gtk.new("CellRendererText"),
		"text", 1,
		gnome.NIL
	);
	col:set_resizable(true);
	list:append_column(col);
	-- }}} init columns
	list:get_selection():set_mode(gtk.SELECTION_SINGLE);
	return true;
end;
-- }}} Guuc:init_tree

-- {{{ Guuc:item_new(id, name, parent) -- add new item to Url_treeUrl
--	return iterator on success
function Guuc:item_new(id, name, parent)
	id = tonumber(id);
	if not id then return nil, "invalid ID specified" end;
	local list = self.list;
	if not list then return nil, "self.list undefined" end;
	local model = list:get_model();
	local iter = gtk.new("GtkTreeIter");
	model:append(iter, parent);
	model:set_value(iter, 0, id);
	model:set_value(iter, 1, tostring(name));
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
	local item_new = self.builder:get_object("UrlPop_new");
	if not item_new then return nil, "menu item UrlPop_new not found" end;
	function item_new_clicked(btn) -- create new URI
		-- {{{ get the parent node
		local list = self.list;
		if not list then return false end;
		local sel = self:get_selected(list);
		local path;
		local id = 0;	-- parent ID
		if sel then
			local model = list:get_model();
			if not model then return false end;
			-- get the parent's ID
			id = model:get_value(sel, 0);
			-- iterator will become invalid after item appending,
			-- store it's path instead
			path = model:get_path(sel);
		end;
		-- }}} get the parent node
		-- {{{ write the item to the DB
		local sql = self.sql;
		if not sql then return false end;
		-- }}} write the item to the DB
		-- {{{ display the item on the Url_treeUrl
		self:item_new(123, "new item №123", sel);
		if path then
			-- unfold the parent item
			list:expand_row(path, false);
		end;
		-- }}} display the item on the Url_treeUrl
		return true;
	end;
	item_new:connect('activate', item_new_clicked);
end;
-- }}} Guuc:init_pop

-- {{{ Guuc:align_hpaned() -- resize Url_hpanUrl
function Guuc:align_hpaned()
	local hpaned = self.builder:get_object("Url_hpanUrl");
	if not hpaned then return nil, "Url_hpanUrl not found" end;
	local wi, he = self.win:get_size(0, 0);
	hpaned:set_position(wi / 2);
	return true;
end;
-- }}} Guuc:align_hpaned

-- {{{ Guuc:loop() -- fall into the gtk.main() loop
function Guuc:loop()
	gtk.main();
end;
-- }}} Guuc:loop

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
