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

--- {{{ Guuc:init_tree() -- initialize bindings and columns for treeUrl
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
	tree:insert_column_with_attributes(
		-1,
		"Name",
		gtk.new("CellRendererText"),
		"text", 0,
		nil
	);
	tree:insert_column_with_attributes(
		-1,
		"URL",
		gtk.new("CellRendererText"),
		"text", 1,
		nil
	);
end;
--- }}} Guuc:init_tree()

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
	local urls = string.format('%q', self.sql.urls);
	local groups = string.format('%q', self.sql.groups);
	local path = nil;
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
	self.builder:get_object("txtName"):set_text("");
	self.builder:get_object("txtUrl"):set_text("");
	tree:get_selection():selected_foreach(
		function(model, path, iter, data)
			self.builder:get_object("txtName"):set_text(
				model:get_value(iter, 0)
			);
			self.builder:get_object("txtUrl"):set_text(
				model:get_value(iter, 1)
			);
		end, nil
	);
end;
-- }}} Guuc:show_url()

-- {{{ Guuc:save_url() -- saves URL info into
function Guuc:save_url(btn)
	local tree = self.builder:get_object("treeUrl");
	local count = tree:get_selection():count_selected_rows();
	local function save(model, path, iter, data)
		count = count - 1;
		if count > 0 then return end;
		self.sql:update_url(
			model:get_value(iter, 2),
			self.builder:get_object("txtName"):get_text(),
			self.builder:get_object("txtUrl"):get_text()
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

-- {{{ Guuc:del_url() -- add a new empty URL
function Guuc:del_url()
	local tree = self.builder:get_object("treeUrl");
	local count = tree:get_selection():count_selected_rows();
	local function delete(model, path, iter, data)
		count = count - 1;
		if count > 0 then return end;
		self.sql.descr = "";
		self.sql.url = "http://";
		self.sql.group = "";
		self.just_added = true;
		self.sql:query(string.format(
			'DELETE FROM %q WHERE `id` = %d',
			self.sql.urls,
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
function Guuc:add_prop()
	local tbl = self.builder:get_object("tableProperty");
	local rows = glib.list_length(tbl:get_children())/3;
	local txt = gtk.gtk_entry_new();
	tbl:attach(txt, 0, 1, rows, rows + 1, gtk.GTK_FILL, gtk.GTK_FILL, 0, 0);
	local txt = gtk.gtk_entry_new();
	tbl:attach(txt, 1, 2, rows, rows + 1, gtk.GTK_FILL, gtk.GTK_FILL, 0, 0);
	local txt = gtk.gtk_entry_new();
	tbl:attach(txt, 2, 3, rows, rows + 1, gtk.GTK_FILL, gtk.GTK_FILL, 0, 0);
	local win = self.builder:get_object("winMain");
	win:show_all();
end;
-- }}} Guuc:add_prop()

-- {{{ Guuc:main()
function Guuc:main()
	-- winMain
	local winMain = self.builder:get_object("winMain");
	winMain:connect("destroy", gtk.main_quit);
	-- menuQuit
	local menuQuit = self.builder:get_object("menuQuit");
	menuQuit:connect("activate", gtk.main_quit);
	-- toolbar
	self.builder:get_object("toolRemove"):connect(
		"clicked",
		function(btn) self:del_url() end
	);
	self.builder:get_object("toolRefresh"):connect(
		"clicked",
		function(btn) self:update_tree() end
	);
	self.builder:get_object("toolAdd"):connect(
		"clicked",
		function(btn) self:add_url() end
	);
	-- properties toolbar
	self.builder:get_object("toolPropertyAdd"):connect(
		"clicked",
		function(btn) self:add_prop() end
	);
	-- buttons
	self.builder:get_object("btnRestore"):connect(
		"pressed",
		function(btn) self:show_url(btn) end
	);
	self.builder:get_object("btnSave"):connect(
		"pressed",
		function(btn) self:save_url(btn) end
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
