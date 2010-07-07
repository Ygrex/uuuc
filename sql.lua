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
		urls = "uuuc",
		groups = "groups",
		tags = "tags",
		-- }}} DB tables we use
		db = "uuuc.sql",
		table = "uuuc",
		url = "",
		group = "",
		descr = "",
		struct = {
			urls = {
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
				["url"] = "INTEGER",
				["name"] = "VARCHAR(65536)",
				["value"] = "VARCHAR(65536)"
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
		return false;
	end;
	url["descr"] = self.descr;
	url["group"] = tonumber(url["group"]);
	if not url["group"] then url["group"] = 0 end;
	self.cur, self.err = self.con:execute(
		'INSERT INTO ' .. self:escape(self.urls) ..
		string.format(
			' (%s) VALUES (%s)',
			self:implode_cols("urls", url)
		)
	);
	if not self.cur then return false end;
	self.err = "";
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
function Sql:implode_cols(table, value, omit)
	local s = "";
	local v = "";
	if not value then v = nil end;
	if not omit then omit = {} end;
	for k in pairs(self.struct[table]) do
		-- omit autoincremented index when values specified
		if not (
			(omit[k] ~= nil)
			or
			( (k == "id") and (value ~= nil) )
		) then
			if s:sub(1, 1) ~= "" then
				s = s .. ",";
				if value then v = v .. "," end;
			end;
			s = s .. "`" .. k .. "`";
			if value then
				if value[k] == nil then value[k] = "" end;
				v = v .. self:escape(value[k]);
			end;
		end;
	end;
	return s, v;
end;
-- }}} Sql:implode_cols(table)

-- {{{ Sql:query()
function Sql:query(s)
	if self.con == nil then self:connect() end;
	local cur;
	cur, self.err = self.con:execute(s);
	if not self.err then self.err = "" end;
	return cur;
end;
-- }}} Sql:query()

-- {{{ Sql:show() -- show table content
function Sql:show()
	local t = self.table;
	if
		(self.urls ~= t) and
		(self.groups ~= t) and
		(self.tags ~= t)
		then return false end;
	if self.con == nil then self:connect() end;
	local s;
	if (t == self.urls) then
		local urls = self:escape(self.urls);
		local groups = self:escape(self.groups);
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
		if #self.group > 0 then
			s = s .. ' WHERE ' ..
				groups .. '.`name` LIKE ' ..
				self:escape(self.group);
		end;
	else
		s = 'SELECT ' ..
			self:implode_cols(t) ..
			' FROM ' ..
			self:escape(self[t]);
	end;
	self.cur, self.err = self.con:execute(s);
	if not self.cur then return false end;
	local r = {};
	while self.cur:fetch(r, "a") do
		if t == self.urls then
			s = '"' .. r["name"] .. '"\t' .. implode_uri(r);
		elseif t == self.groups then
			s = r["parent"] ..
				'\t"' ..
				r["name"] ..
				'"\t"' ..
				r["descr"] .. '"';
		else
			s = r["alias"] ..
				'\t"' ..
				r["name"] .. '"';
		end;
		print(r["id"], s);
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
		s = "CREATE TABLE IF NOT EXISTS " ..
			self:escape(self[k]) ..
			" (";
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

-- {{{ Sql:update_url(id, name, url, group, prop) -- update URL in DB
function Sql:update_url(id, name, url, group, prop)
	if not url then
		self.err = "invalid URL";
		return false;
	end;
	if self.con == nil then self:connect() end;
	local urls = self:escape(self.urls);
	local groups = self:escape(self.groups);
	id = tonumber(id);
	if not id then self.err = "Invalid Id" ; return false end;
	group = tonumber(group);
	if not group then
		group = "";
	else
		group = ",`group` = " .. group;
	end;
	local url = parse_uri(url);
	local s = 'UPDATE ' .. urls ..
		' SET ' ..
		'`scheme` = ' .. self:escape(url["scheme"]) .. ',' ..
		'`delim` = ' .. self:escape(url["delim"]) .. ',' ..
		'`userinfo` = ' .. self:escape(url["userinfo"]) .. ',' ..
		'`regname` = ' .. self:escape(url["regname"]) .. ',' ..
		'`path` = ' .. self:escape(url["path"]) .. ',' ..
		'`query` = ' .. self:escape(url["query"]) .. ',' ..
		'`fragment` = ' .. self:escape(url["fragment"]) .. ',' ..
		'`descr` = ' .. self:escape(name) ..
		group ..
		' WHERE `id` = ' .. id;
	self.cur, self.err = self.con:execute(s);
	if not self.cur then return false end;
	if prop ~= nil then
		local s = 'DELETE FROM ' .. groups ..
			' WHERE `url` = ' .. id;
		self.cur, self.err = self.con:execute(s);
		for k, v in ipairs(prop) do
			if v[1] ~= "" then
				s = 'INSERT INTO ' .. groups ..
					string.format(
					' (%s) VALUES(%s)',
					self:implode_cols(
						"groups",
						{
						["url"] = id,
						["name"] = v[1],
						["value"] = v[2]
						}
					));
				self.cur, self.err = self.con:execute(s);
			end;
		end;
	end;
	if not self.err then self.err = "" end;
	return true;
end;
-- }}} Sql:update_url(id, name, url, group)

-- {{{ Sql:escape(s) -- escape string for sqlite injection
function Sql:escape(s)
	if not s then return '""' end;
	return '"' .. string.gsub(s, '"', '""') .. '"';
end;
-- }}} Sql:escape(s)

-- }}} Sql object

-- vim: set foldmethod=marker:
