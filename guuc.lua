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
	local model = tree:get_model();
	local iter = gtk.new("TreeIter");
	model:clear();
	-- sql
	local urls = string.format('%q', self.sql.urls);
	local groups = string.format('%q', self.sql.groups);
	s = 'SELECT ' ..
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
		groups .. '.`id`';
	local r = self.sql:query(s);
	if not r then error(self.sql.err) end;
	local r = {};
	-- fullfill
	while self.sql.cur:fetch(r, "a") do
		urls = implode_uri(r);
		model:append(iter, nil);
		model:set(iter,
			0, r["name"],
			1, descr,
			2, urls,
			-1);
	end;
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
