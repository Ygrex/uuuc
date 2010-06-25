require "luasql.sqlite3";

dofile "utils.lua";

-- {{{ Sql object

-- {{{ Sql properties and metatable
Sql = { };
Sql_mt = { __index = Sql };
-- }}} Sql property and metatable

-- {{{ Sql:new(VOID) -- constructor
function Sql:new()
	local o = {
		-- {{{ DB tables we use
		table = "uuuc",
		groups = "groups",
		tags = "tags",
		-- }}} DB tables we use
		db = "uuuc.sql",
		url = "",
		group = "",
		descr = "",
		struct = {
			table = {
				["id"] = "INTEGER",
				["group"] = "INTEGER",
				["icon"] = "VARCHAR(256)",
				["scheme"] = "VARCHAR(256)",
				["delim"] = "VARCHAR(256)",
				["userinfo"] = "VARCHAR(1024)",
				["regname"] = "VARCHAR(256)",
				["path"] = "VARCHAR(4096)",
				["query"] = "VARCHAR(4096)",
				["fragment"] = "VARCHAR(4096)",
				["descr"] = "VARCHAR(65536)"
				},
			groups = {
				["id"] = "INTEGER",
				["parent"] = "INTEGER",
				["icon"] = "VARCHAR(256)",
				["name"] = "VARCHAR(65536)",
				["descr"] = "VARCHAR(65536)"
				},
			tags = {
				["id"] = "INTEGER",
				["alias"] = "INTEGER",
				["name"] = "VARCHAR(65536)"
				}
		}
	};
	setmetatable(o, Sql_mt);
	o.env = luasql.sqlite3();
	return o;
end;
-- }}} Sql:new(VOID)

-- {{{ Sql:set(name, value) -- set any property if it exists
function Sql:set(name, value)
	if self[name] ~= nil and type(self[name]) == "string" then
		self[name] = value;
		return true;
	end;
	return false;
end;
-- }}} Sql:set(name, value)

-- {{{ Sql:add() -- add record
function Sql:add()
	if not self.url then
		self.err = "URL must be specified";
		return false;
	end;
	if not self.descr then self.descr = self.url end;
	if self.con == nil then self:connect() end;
	local url = parse_uri(self.url);
	if not url then
		self.err = "Invalid URL";
		print("AI:", self.url);
		print("UE:", encode_uri(self.url));
		return false;
	end;
	url["descr"] = self.descr;
	if self.group ~= "" then
		-- URI group specified [by name]
		self.cur, self.err = self.con:execute(
			string.format(
				'SELECT %s FROM %q WHERE `name` LIKE %q',
				self:implode_cols("groups"),
				self.groups,
				self.group
			)
		);
		if not self.cur then return false end;
		local r = {};
		local group = self.cur:fetch(r, "a");
		if not group then
			-- create a new group
			self.cur, self.err = self.con:execute(
				string.format(
					'INSERT INTO %q (%s) VALUES (%s)',
					self.groups,
					self:implode_cols(
						"groups",
						{
						["parent"] = 0,
						["icon"] = "",
						["name"] = self.group,
						["descr"] = ""
						}
					)
				)
			);
			if not self.cur then return false end;
			self.cur, self.err = self.con:execute(
				string.format(
					'SELECT MAX(`id`) FROM %q',
					self.groups
				)
			);
			if not self.cur then return false end;
			url["group"] = self.cur:fetch();
		else
			-- group found
			url["group"] = r["id"];
		end;
	end;
	local s, v = self:implode_cols("table", url);
	self.cur, self.err = self.con:execute(
		string.format(
			'INSERT INTO %q (%s) VALUES (%s)',
			self.table,
			self:implode_cols("table", url)
		)
	);
	if not self.cur then return false end;
	return true;
end;
-- }}} Sql:add()

-- {{{ Sql:showdb() -- show available tables
function Sql:showdb(...)
	if self.con == nil then self:connect() end;
	self.cur, self.err = self.con:execute([[
		SELECT `name` FROM `sqlite_master`
		WHERE `type` LIKE "table"
		AND NOT `name` LIKE "sqlite_%"
	]]);
	if not self.cur then return false end;
	local t = {};
	while self.cur:fetch(t, "a") do print(t.name) end;
	return true;
end;
-- }}} Sql:showdb()

-- {{{ Sql:implode_cols(table) -- implode quoted col names for the given table
function Sql:implode_cols(table, value)
	local s = "";
	local v = "";
	if not value then v = nil end;
	for k in pairs(self.struct[table]) do
		-- omit autoincremented index when values specified
		if not ( (k == "id") and (value ~= nil) ) then
			if s:sub(1, 1) ~= "" then
				s = s .. ",";
				if value then v = v .. "," end;
			end;
			s = s .. "`" .. k .. "`";
			if value then
				if value[k] == nil then value[k] = "" end;
				v = v .. string.format("%q", value[k]);
			end;
		end;
	end;
	return s, v;
end;
-- }}} Sql:implode_cols(table)

-- {{{ Sql:show() -- show table content
function Sql:show(t)
	if (self[t] == nil) or (type(self[t]) ~= "string") then
		return false
	end;
	if self.con == nil then self:connect() end;
	self.cur, self.err = self.con:execute(
		string.format(
			'SELECT %s FROM %q',
			self:implode_cols(t),
			self[t]
		)
	);
	if not self.cur then return false end;
	local r = {};
	while self.cur:fetch(r, "a") do
		print(r["id"], implode_uri(r));
	end;
	return true;
end;
-- }}} Sql:show()

-- {{{ Sql:create() -- create tables and DB file if not yet
function Sql:create(...)
	for _, v in pairs { self.table, self.groups, self.tags } do
		if string.sub(v, 1, 7) == "sqlite_" then
			self.err = 'Table name cannot begin with "sqlite_"';
			return false;
		end;
	end;
	if self.con == nil then self:connect() end;
	local s;
	for k, v in pairs(self.struct) do
		s = string.format(
			"CREATE TABLE IF NOT EXISTS %q (",
			self[k]
		);
		for i, j in pairs(v) do
			s = s .. "`" .. i .. "` " .. j .. ",";
		end;
		s = s .. 'PRIMARY KEY (`id` AUTOINCREMENT) )';
		self.cur, self.err = self.con:execute(s);
	end;
	return self.cur ~= nil;
end;
-- }}} Sql:create()

-- {{{ Sql:connect(VOID) -- connect ODBC
function Sql:connect()
	self.con, self.err = self.env:connect(self.db);
	return self.con;
end;
-- }}} Sql:connect(VOID)

-- {{{ Sql:close(VOID) -- close ODBC connection
function Sql:close()
	if self.con ~= nil then
		if self.cur ~= nil then self.cur:close() end;
		if self.con:close() then
			self.cur, self.con = nil, nil;
			return true;
		end;
		return false;
	end;
	return true;
end;
-- }}} Sql:close(VOID)

-- }}} Sql object

-- vim: set foldmethod=marker:
