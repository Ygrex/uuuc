require "gtk";

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
	local c = gtk.tree_view_column_new_with_attributes(
		"Name",
		gtk.new("CellRendererText"),
		"text", 0,
		nil
	);
	c:set_resizable(true);
	tree:append_column(c);
	c = gtk.tree_view_column_new_with_attributes(
		"URL",
		gtk.new("CellRendererText"),
		"text", 1,
		nil
	);
	c:set_resizable(true);
	tree:append_column(c);
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
	local urls = self.sql:escape(self.sql.urls);
	local groups = self.sql:escape(self.sql.groups);
	local path = nil;
	-- amend orphaned elements
	self.sql:query('UPDATE ' .. urls ..
		' SET `group` = (' ..
			'SELECT ' ..
				'COALESCE(`b`.`id`,0) ' ..
				'FROM ' .. urls .. ' AS `a` ' ..
				'LEFT JOIN ' .. urls .. ' AS `b` ' ..
					'ON `a`.`group` = `b`.`id` ' ..
				'WHERE `a`.`id` = ' .. urls .. '.`id`' ..
		') ' ..
		'WHERE `group` > 0');
	-- {{{ deep_iter(id, model, iter)
	-- add items from group specified by `id` to GtkTreeModel
	-- under iteration specified by `iter`
	-- and iterate recursively thru subgroups
	local function deep_iter(id, model, iter)
		local s_url = 'SELECT ' ..
			urls .. '.`id`,' ..
			urls .. '.`scheme`,' ..
			urls .. '.`delim`,' ..
			urls .. '.`userinfo`,' ..
			urls .. '.`regname`,' ..
			urls .. '.`path`,' ..
			urls .. '.`query`,' ..
			urls .. '.`fragment`,' ..
			urls .. '.`descr`' ..
			' FROM ' ..
			urls ..
			' WHERE ' ..
			urls .. '.`group`' ..
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
				2, r["id"],
				-1
			);
			deep_iter(r["id"], model, subiter);
		end;
		cur:close();
	end;
	-- }}} deep_iter(id, model, iter)
	model:clear();
	deep_iter(0, model, nil);
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
			s = "SELECT `name`, `value` FROM " ..
				self.sql:escape(self.sql.groups) ..
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
			self.builder:get_object("tableProperty"):get_children(),
			function (data, udata)
				local row = data:get_data("tbl_row").value;
				local col = data:get_data("tbl_col").value;
				if not prop[row] then prop[row] = {} end;
				prop[row][col] = data:get_text();
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
			'DELETE FROM %s WHERE `url` = %d',
			self.sql:escape(self.sql.groups),
			model:get_value(iter, 2)
		));
		self.sql:query(string.format(
			'DELETE FROM %s WHERE `id` = %d',
			self.sql:escape(self.sql.urls),
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
		{value, gtk.GTK_FILL + gtk.GTK_EXPAND, gtk.gtk_entry_new}
	};
	local elements = {};
	local view = self.builder:get_object("scrwinProperty");
	for k, v in ipairs(prop) do
	local txt = v[3]();
	table.insert(elements, txt);
	txt:set_text(v[1]);
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

-- {{{ Guuc:main()
function Guuc:main()
	local bld = self.builder;
	-- winMain
	local winMain = bld:get_object("winMain");
	winMain:connect("destroy", gtk.main_quit);
	-- menuQuit
	local menuQuit = bld:get_object("menuQuit");
	menuQuit:connect("activate", gtk.main_quit);
	-- toolbar
	bld:get_object("toolRemove"):connect(
		"clicked",
		function(btn) self:del_url() end
	);
	bld:get_object("toolRefresh"):connect(
		"clicked",
		function(btn) self:update_tree() end
	);
	bld:get_object("toolAdd"):connect(
		"clicked",
		function(btn) self:add_url() end
	);
	-- properties toolbar
	bld:get_object("toolPropertyAdd"):connect(
		"clicked",
		function(btn)
			local e = self:add_prop("Attribute", "Value");
			if e[1] then e[1]:grab_focus() end;
		end
	);
	-- buttons
	bld:get_object("btnRestore"):connect(
		"pressed",
		function(btn) self:show_url(btn) end
	);
	bld:get_object("btnSave"):connect(
		"pressed",
		function(btn) self:save_url(btn) end
	);
	local winFile = bld:get_object("winFile");
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
	-- display DB content
	self:update_tree();
	self:init_tree();
	winMain:show();
	gtk.main();
	return true;
end;
-- }}} Guuc:main()

-- }}} Guuc object

-- vim: set foldmethod=marker:
