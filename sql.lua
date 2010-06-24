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
		table = "uuuc",
		db = "uuuc.sql",
		url = "",
		descr = ""
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
	for k, v in pairs(url) do print(k, v) end;
	error("not implemented yet");
	-- {{{ parse URL
	local s, e = string.find(self.url, "^%a[%a%d+.-]*:");
	local scheme, rest;
	if not s then
		scheme = "http";
		rest = self.url;
	else
		scheme = string.sub(self.url, 1, e - 1);
		rest = string.sub(self.url, e + 1);
	end;
	local delim = false;
	if string.sub(rest, 1, 2) == "//" then
		rest = rest:sub(3);
		delim = true;
	end;
	local sub_delims = "$&'()*+,;=!";
	local unreserved = "%w._~-";
	local pct_encoded = "\%%x";
	s, e = string.find(
		rest,
		"^[:" ..
			sub_delims ..
			pct_encoded ..
			unreserved ..
		"]+@");
	local userinfo;
	if not s then
		userinfo = "";
	else
		userinfo = string.sub(rest, 1, e - 1);
		rest = string.sub(rest, e + 1);
	end;
	local domaintypes = 0;
	local domaintype = "";
	s, e = string.find(
		rest,
		"%d+\.%d+\.%d+\.%d+"
		);
	if s then
		domain = rest:sub(1, e);
		rest = rest:sub(e + 1);
		-- IPv4
		domaintype = 1;
	else
		s, e = string.find(
			rest,
			"^[" ..
			sub_delims ..
			pct_encoded ..
			unreserved ..
			"]+"
		);
		if s then
		else
			s, e = string.find(
			rest,
			"[%x:]+"
			);
		end;		
	end;
	print("scheme: " .. scheme);
	print("userinfo: ", userinfo);
	print("rest: " .. rest);
	-- }}} parse URL
	error("not implemented yet");
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

-- {{{ Sql:show() -- show table content
function Sql:show(...)
	if self.con == nil then self:connect() end;
	self.cur, self.err = self.con:execute(
		string.format('SELECT * FROM %q', self.table)
	);
	if not self.cur then return false end;
	local t = {};
	while self.cur:fetch(t, "a") do print(unpack(t)) end;
	return true;
end;
-- }}} Sql:show()

-- {{{ Sql:create() -- create table and DB file if not exist
function Sql:create(...)
	if string.sub(self.table, 1, 7) == "sqlite_" then
		self.err = 'Table name cannot begin with "sqlite_"';
		return false;
	end;
	if self.con == nil then self:connect() end;
	self.cur, self.err = self.con:execute(
		'CREATE TABLE IF NOT EXISTS ' ..
		string.format("%q", self.table) ..
		[[(
		id INTEGER,
		icon VARCHAR(256),
		prot VARCHAR(256),
		domain VARCHAR(256),
		res VARCHAR(4096),
		auth VARCHAR(1024),
		descr VARCHAR(65536),
		PRIMARY KEY (id AUTOINCREMENT)
		)]]
	);
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
