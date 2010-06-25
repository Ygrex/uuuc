dofile "sql.lua";

-- {{{ Act object

-- {{{ Act properties and metatable
Act = {};
Act_mt = { __index = Act };
-- }}} Act properties and metatable

-- {{{ Act:new(parent) -- constructor
function Act:new(parent)
	local o = {
		-- {{{ known actions
		new = { func = function() return parent.sql:create() end,
			pri = 16 },
		add = { func = function() return parent.sql:add() end,
			prin = 12 },
		showdb = { func = function() return parent.sql:showdb() end,
			pri = 8 },
		show = { func = function()
				return parent.sql:show("table") end,
			pri = 8 },
		showgroups = { func = function()
				return parent.sql:show("groups") end,
			pri = 8 },
		help = { func = function() return parent:help() end,
			pri = 0 },
		-- }}} known actions
	};
	setmetatable(o, Act_mt);
	o.parent = parent;
	return o;
end;
-- }}} Act:new(parent)

-- {{{ Act:set(name) -- queue the action
function Act:set(name)
	
	if self[name].func ~= nil then
		self[name].checked = true;
		return true;
	end;
	return false;
end;
-- }}} Act:set(name)

-- }}} Act object

-- {{{ Getopt object

-- {{{ Getopt properties and metatable
Getopt = {};
Getopt_mt = { __index = Getopt };
-- }}} Getopt properties and metatable

-- {{{ Getopt:new(VOID) -- constructor
function Getopt:new()
	local o = {};
	setmetatable(o, Getopt_mt);
	o.sql = Sql:new();
	o.act = Act:new(o);
	-- {{{ known positional parameters
	local function act_set(a, b)
		o.act:set(a)
	end;
	local function act_setd(a, b)
		return function(c, d) o.act:set(a) end;
	end;
	local function sql_set(k, v)
		o.sql:set(k, v)
	end;
	local function sql_setd(a, b)
		return function(c, b) o.sql:set(a, b) end;
	end;
	o.entries = {
		help = { func = act_set,
			descr = "show this help"},
		show = {func = act_set,
			descr = "show a table content",
			default = o.sql.table},
		showdb = {func = act_set,
			descr = "display available tables within DB"},
		create = {func = act_setd("new"),
			descr = "create table and DB file if not exist"},
		new = {func = act_set,
			descr = "create table and DB file if not exist"},
		add = {func = act_set,
			descr = "add entry to the DB"},
		groups = {func = sql_set,
			descr = "name of table with groups",
			default = o.sql.groups},
		tags = {func = sql_set,
			descr = "name of table with tags",
			default = o.sql.tags},
		table = {func = sql_set,
			descr = "table name to read from file",
			default = o.sql.table},
		db = {func = sql_set,
			descr = "DB file to open",
			default = o.sql.db},
		file = {func = sql_setd("db"),
			descr = "DB file to open",
			default = o.sql.db},
		url = {func = sql_set,
			descr = "URL",
			default=""},
		descr = {func = sql_set,
			descr = "URL description"}
	}
	-- }}} known positional parameters
	return o;
end;
-- }}} Getopt:new(VOID)

-- {{{ Getopt:parse_flags (argv) -- parse positional parameters
function Getopt:parse_flags(argv)
	local flags = {}
	for i = #argv, 1, -1 do
		local flag = argv[i]:match("^%-%-(.*)")
		if flag then
			local var,val = flag:match("([a-z_%-]*)=(.*)")
			if val then
				flags[var] = val
			else
				flags[flag] = true
			end
			table.remove(argv, i)
		end
	end
	return flags, argv
end
-- }}} Getopt:parse_flags (argv)

-- {{{ Getopt:help(...) -- show usage information
function Getopt:help(...)
	print("Usage: " .. self.arg0 .. " [GNU style options] ...");
	print();
	print("GNU long options:");
	local keys = {};
	for k in pairs(self.entries) do table.insert(keys, k) end;
	table.sort(keys);
	local tab = 4;
	local prefix = string.rep(" ", tab) .. "--";
	local max = 0;
	local function show_default(s) return "[=" .. s .. "]" end;
	for _, v in pairs(keys) do
		self.entries[v].width =
			unistring.u8_strwidth(v, "");
		if self.entries[v].default then
			self.entries[v].width =
				self.entries[v].width +
				unistring.u8_strwidth(
					show_default(
						self.entries[v].default
					), ""
				);
		end;
		if self.entries[v].width > max then
			max = self.entries[v].width;
		end;
	end;
	max = max + tab;
	local postfix;
	for _, v in ipairs(keys) do
		postfix = string.rep(
			" ",
			max - self.entries[v].width
		);
		if self.entries[v].default then
			print(
				prefix
				.. v
				.. show_default(
					self.entries[v].default
				) .. postfix
				.. self.entries[v].descr
			)
		else
			print(
				prefix
				.. v
				.. postfix
				.. self.entries[v].descr
			)
		end;
	end;
	return true;
end;
-- }}} Getopt:help(...)

-- {{{ Getopt:main (arg)
function Getopt:main(arg)
	self.arg0 = arg[0];
	local argv = {};
	for k, i in pairs(arg) do
		if k > 0 then argv[k] = arg[k] end;
	end;
	local flags, args = self:parse_flags(argv);
	for k, i in pairs(flags) do
		if self.entries[k] == nil then
			print("Unknown argument: " .. k ..
				" (ignoring)");
		else
			if self.entries[k].func ~= nil then
				self.entries[k].func(k, i);
			end;
		end;
	end;
	-- sort actions according to their priorities
	local acts = {};
	for k, v in pairs(self.act) do
		if (type(v) == "table") and v.checked then
			v.desc = k;
			for i, j in ipairs(acts) do
				if j.pri < v.pri then
					table.insert(acts, i, v);
					v = nil;
					break;
				end;
			end;
			if v then table.insert(acts, v) end;
		end;
	end;
	if #acts < 1 then
		self.act["help"].func();
	else
		for _, i in ipairs(acts) do
			if not i.func() then
				print('While executing "' .. i.desc ..
					'" an error occured\n\t',
					self.sql.err);
			end;
		end;
	end;
	return 0;
end;
-- }}} Getopt:main (arg)

-- }}} Getopt object

-- vim: set foldmethod=marker:
