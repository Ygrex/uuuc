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
		["glade_file"] = "uuuc.glade"
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

-- {{{ Guuc:update_tree() -- refresh treeUrl content
function Guuc:update_tree()
	-- gtk
	local tree = self.builder:get_object("treeUrl");
	-- sql
	local urls = string.format('%q', self.sql.urls);
	local groups = string.format('%q', self.sql.groups);
	-- {{{ local functions
	-- {{{ item_click(tree, event)
	-- callback function on a click inside GtkTreeView
	local function item_click(tree, event)
		if (event["button"].button == 1) and
			(event["type"] == gdk.GDK_2BUTTON_PRESS)
			then
			local model, iter;
			tree:get_selection():selected_foreach(
				function(model, path, iter, data)
					local url = model:get_value(
							iter,
							2
						);
					if #url < 1 then return false end;
					io.popen(string.format(
						"xdg-open %q",
						url
					), "r");
				end, nil
			);
		elseif (event["button"].button == 3) then
			return nil;
		end;
	end
	-- }}} item_click(tree, event)
	-- {{{ deep_iter(id, model, iter)
	-- add items from group specified by `id` to GtkTreeModel
	-- under iteration specified by `iter`
	-- and iterate recursively thru subgroups
	local function deep_iter(id, model, iter)
		local s_gr = 'SELECT ' ..
			groups .. '.`id`,' ..
			groups .. '.`parent`,' ..
			groups .. '.`icon`,' ..
			groups .. '.`name`,' ..
			groups .. '.`descr`' ..
			' FROM ' ..
			groups ..
			' WHERE ' ..
			groups .. '.`parent` = ' .. id;
		local s_url = 'SELECT ' ..
			urls .. '.`id`,' ..
			groups .. '.`name`,' ..
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
			' LEFT JOIN ' ..
			groups ..
			' ON ' ..
			urls .. '.`group`' ..
			' = ' ..
			groups .. '.`id`' ..
			' WHERE ' ..
			urls .. '.`group`' ..
			' = ' .. id;
		-- groups
		local cur = self.sql:query(s_gr);
		if not cur then error(self.sql.err) end;
		local r = {};
		local subiter = gtk.new("TreeIter");
		while cur:fetch(r, "a") do
			model:append(subiter, iter);
			model:set(subiter,
				0, r["name"],
				1, "",
				2, "",
				-1
			);
			deep_iter(r["id"], model, subiter);
		end;
		cur:close();
		-- URLs
		cur = self.sql:query(s_url);
		if not cur then error(self.sql.err) end;
		while cur:fetch(r, "a") do
			model:append(subiter, iter);
			model:set(subiter,
				0, r["name"],
				1, r["descr"],
				2, implode_uri(r),
				-1
			);
		end;
		cur:close();
	end;
	-- }}} deep_iter(id, model, iter)
	-- }}} local functions
	tree:add_events(gdk.BUTTON_PRESS_MASK);
	tree:connect(
		'button_press_event',
		item_click
	);
	tree:get_model():clear();
	deep_iter(0, tree:get_model(), nil);
	tree:insert_column_with_attributes(
		-1,
		"group",
		gtk.new("CellRendererText"),
		"text", 0,
		nil
	);
	tree:insert_column_with_attributes(
		-1,
		"name",
		gtk.new("CellRendererText"),
		"text", 1,
		nil
	);
	tree:insert_column_with_attributes(
		-1,
		"url",
		gtk.new("CellRendererText"),
		"text", 2,
		nil
	);
	tree:expand_all();
	return true;
end;
-- }}} Guuc:update_tree()

-- {{{ Guuc:main()
function Guuc:main()
	-- winMain
	local winMain = self.builder:get_object("winMain");
	winMain:connect("destroy", gtk.main_quit);
	-- menuQuit
	local menuQuit = self.builder:get_object("menuQuit");
	menuQuit:connect("activate", gtk.main_quit);
	-- show
	self:update_tree();
	winMain:show();
	gtk.main();
	return true;
end;
-- }}} Guuc:main()

-- }}} Guuc object

-- vim: set foldmethod=marker:
