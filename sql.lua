-- {{{ load sqlite3
assert(type(LIBS) == "table", "LIBS not specified or incorrect table");
local LIB_SQLITE3 = tostring(LIBS.sqlite3);
assert(LIB_SQLITE3, "sqlite3 library is not specified");

local dlffi = require("dlffi");

local sqlite3 = {
{
	"open",
	dlffi.ffi_type_sint,
	{
		dlffi.ffi_type_pointer,	-- filename
		dlffi.ffi_type_pointer,	-- ppDb
	}
},
{
	"close",
	dlffi.ffi_type_sint,
	{ dlffi.ffi_type_pointer }
},
{
	"errmsg",
	dlffi.ffi_type_pointer,
	{ dlffi.ffi_type_pointer }
},
{
	"prepare_v2",
	dlffi.ffi_type_sint,
	{
		dlffi.ffi_type_pointer,	-- db
		dlffi.ffi_type_pointer,	-- zSql
		dlffi.ffi_type_sint,	-- nByte
		dlffi.ffi_type_pointer,	-- ppStmt
		dlffi.ffi_type_pointer,	-- pzTail
	}
},
-- {{{ sqlite3_stmt interface
{
	"finalize",
	dlffi.ffi_type_sint,
	{ dlffi.ffi_type_pointer }
},
{
	"column_count",
	dlffi.ffi_type_sint,
	{ dlffi.ffi_type_pointer }
},
{
	"column_type",
	dlffi.ffi_type_sint,
	{ dlffi.ffi_type_pointer, dlffi.ffi_type_sint }
},
{
	"column_int",
	dlffi.ffi_type_sint,
	{ dlffi.ffi_type_pointer, dlffi.ffi_type_sint }
},
{
	"column_bytes",
	dlffi.ffi_type_sint,
	{ dlffi.ffi_type_pointer, dlffi.ffi_type_sint }
},
{
	"column_double",
	dlffi.ffi_type_double,
	{ dlffi.ffi_type_pointer, dlffi.ffi_type_sint }
},
{
	"column_text",
	dlffi.ffi_type_pointer,
	{ dlffi.ffi_type_pointer, dlffi.ffi_type_sint }
},
{
	"column_blob",
	dlffi.ffi_type_pointer,
	{ dlffi.ffi_type_pointer, dlffi.ffi_type_sint }
},
{
	"step",
	dlffi.ffi_type_sint,
	{ dlffi.ffi_type_pointer }
},
-- }}} sqlite3_stmt interface
["OK"]		= 0,
["ERROR"]	= 1,
["ROW"]		= 100,
["DONE"]	= 101,
["INTEGER"]	= 1,
["FLOAT"]	= 2,
["TEXT"]	= 3,
["BLOB"]	= 4,
["NULL"]	= 5,
};

for i = 1, #sqlite3, 1 do
	local v = sqlite3[i];
	local n = v[1];
	v[1] = "sqlite3_" .. v[1];
	local f, e = dlffi.load(LIB_SQLITE3, unpack(v));
	assert(f ~= nil, e and e or "memory allocation failed");
	sqlite3[n] = f;
end;
-- }}} load sqlite3

-- {{{ Sqlite3 -- Sqlite3 class
assert(type(TBL) == "table", "TBL is not specified");

local Sqlite3 = {
	["_type"] = "object",	-- for a correct work of Dlffi methods
	["tbl"] = {		-- list of interesting tables
		["url"]		= tostring(TBL.url),	-- table for URLs
		["prop"]	= tostring(TBL.prop),	--[[ table for available
								properties --]]
		["val"]		= tostring(TBL.val),	-- URLs' properties
	},
	["struct"] = {
		["url"]		= {
				["id"]		= "INTEGER",
				["parent"]	= "INTEGER DEFAULT 0",
				["unfold"]	= "INTEGER DEFAULT 0",
				["scheme"]	= "VARCHAR(256)",
				["delim"]	= "VARCHAR(256)",
				["userinfo"]	= "VARCHAR(1024)",
				["regname"]	= "VARCHAR(256)",
				["path"]	= "VARCHAR(4096)",
				["query"]	= "VARCHAR(4096)",
				["fragment"]	= "VARCHAR(4096)",
				["misc"]	= "VARCHAR(65536)",
			},
		["prop"]	= {
				["id"]		= "INTEGER",
				["misc"]	= "VARCHAR(65536)",
			},
		["val"]	= {
				["id"]		= "INTEGER",
				["misc"]	= "VARCHAR(65536)",
			},
	},
	["constraint"] = {
		["url"]		= {
				"PRIMARY KEY (`id` AUTOINCREMENT)",
				string.format(
					[[FOREIGN KEY(`parent`) ]] ..
					[[REFERENCES `%s`(`id`) ]] ..
					[[ON DELETE SET DEFAULT ]] ..
					[[ON UPDATE CASCADE ]] ..
					[[DEFERRABLE INITIALLY DEFERRED ]],
					TBL.url
				)
			},
		["val"]		= {
				"PRIMARY KEY (`id` AUTOINCREMENT)"
			},
		["prop"]		= {
				"PRIMARY KEY (`id` AUTOINCREMENT)"
			},
	},
};
-- }}} Sqlite3

-- {{{ Sqlite3:new(filename)	-- constructor
function Sqlite3:new(filename)
	local ppDb = dlffi.dlffi_Pointer();
	local r, e = sqlite3.open(filename, dlffi.dlffi_Pointer(ppDb));
	if r ~= 0 then
		if r == nil then return nil, e end;
		return nil, string.format(
			"sqlite3_open() returned %s",
			tostring(r)
		);
	end;
	local o, e = dlffi.Dlffi:new(
		{self, sqlite3},
		ppDb,
		sqlite3.close,
		nil	-- no constructors in sqlite3
	);
	if o == nil then return nil, e end;
	o.filename = filename;
	local r, e = o:init();
	if not r then return nil, e end;
	return o;
end;
-- }}} Sqlite3:new

-- {{{ Sqlite3:init()	-- prepare DB if not yet
function Sqlite3:init()
	for k, v in pairs(self.tbl) do
		local fields = {};
		for k, v in pairs(self.struct[k]) do
			table.insert(
				fields,
				string.format("`%s` %s", k, v)
			);
		end;
		local que = string.format([[
			CREATE TABLE IF NOT EXISTS `%s` (%s, %s)
			]],
			v,
			table.concat(fields, ","),
			table.concat(self.constraint[k], ",")
		);
		local r, e = self:query(que);
		if not r then return nil, e end;
	end;
	local que = string.format("PRAGMA FOREIGN_KEYS = ON");
	local r, e = self:query(que);
	if not r then return nil, e end;
	return true;
end;
-- }}} Sqlite3:init

-- {{{ Sqlite3:query(stmt) -- execute query and return results
function Sqlite3:query(stmt)
	local stmt = tostring(stmt);
	if not stmt then stmt = "" end;
	local prep = dlffi.dlffi_Pointer();
	local errmsg = "dlffi_Pointer() failed";
	if not prep then return nil, errmsg end;
	-- compile the statement
	local r, e = self:prepare_v2(
		stmt,
		#stmt + 1,
		dlffi.dlffi_Pointer(prep),
		dlffi.NULL	-- only the 1st statement will be compiled
	);
	if r ~= sqlite3.OK then
		if not r then return nil, e end;
		return nil, string.format(
			"sqlite3_prepare_v2() returned %s",
			tostring(r)
		);
	end;
	local funcs = {
		["finalize"]		= sqlite3.finalize,
		["column_count"]	= sqlite3.column_count,
		["column_type"]		= sqlite3.column_type,
		["column_int"]		= sqlite3.column_int,
		["column_double"]	= sqlite3.column_double,
		["column_text"]		= sqlite3.column_text,
		["column_blob"]		= sqlite3.column_blob,
		["column_bytes"]	= sqlite3.column_bytes,
		["step"]		= sqlite3.step,
	};
	-- make a Dlffi object for the statement handling
	local obj, e = dlffi.Dlffi:new(
		{ funcs },
		prep,
		funcs.finalize,
		nil
	);
	if not obj then return nil, e end;
	-- read the result
	local res = {};
	local typed = {
		{ "column_int" },			-- SQLITE_INTEGER
		{ "column_double" },			-- SQLITE_FLOAT
		{ "column_text", "column_bytes" },	-- SQLITE_TEXT
		{ "column_blob", "column_bytes" },	-- SQLITE_BLOB
	};
	while true do
		local r, e = obj:step();
		if r == sqlite3.DONE then break end;
		if r == sqlite3.ROW then
			-- the row fetched
			local row = {};
			local cols, e = obj:column_count();
			if cols == nil then return nil, e end;
			-- iterate through columns
			for i = 0, cols - 1, 1 do
				-- get the column type
				local t, e = obj:column_type(i);
				if not t then return nil, e end;
				local func = typed[t];
				if func ~= nil then
					local val, e = obj[func[1]](obj, i);
					if not val then return nil, e end;
					if func[2] then
						-- get the field length
						local len, e = obj[func[2]](
							obj, i
						);
						if not len then
							return nil, e;
						end;
						-- fetch data
						val = dlffi.dlffi_Pointer(
							val
						):tostring(len);
						if not val then
							return nil, errmsg;
						end;
					end;
					-- attach the field
					table.insert(row, val);
				else
					-- func == nil
					if t == sqlite3.NULL then
						table.insert(
							row,
							dlffi.NULL
						);
					else
						return nil, "Incorrect " ..
							"column type: " ..
							tostring(t);
					end;
				end;
			end; -- iterate through columns
			-- attach the row
			table.insert(res, row);
		else
			-- an error occured
			if r == nil then return nil, e end;
			return nil, string.format(
				"sqlite3_step() returned %s",
				tostring(r)
			);
		end;
	end; -- read the result
	-- all done, return the result table
	return res;
end;
-- }}} Sqlite3:query

--[==[
-- {{{ Sql object

-- {{{ Sql properties and metatable
Sql = { };
Sql_mt = { __index = Sql };
-- }}} Sql property and metatable

-- {{{ Sql:new(VOID) -- constructor
function Sql:new()
	local o = {
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
				},
			prop_groups = {
				["id"] = "INTEGER",
				["name"] = "VARCHAR(65536)"
				},
			properties = {
				["id"] = "INTEGER",
				["group"] = "INTEGER",
				["type"] = "INTEGER",
				["caption"] = "INTEGER",
				["list"] = "VARCHAR(4294967296)",
				["default"] = "VARCHAR(4294967296)"
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
		'INSERT INTO `urls` ' ..
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

-- {{{ Sql:groups_get(VOID) -- fetch list of groups of properties
function Sql:groups_get()
	if self.con == nil then self:connect() end;
	if not self.con then return nil end;
	local que = 'SELECT `id`,`name` FROM `prop_groups` ORDER BY `name`';
	local cur;
	cur, self.err = self.con:execute(que);
	return cur;
end;
-- }}} Sql:groups_get

-- {{{ Sql:props_get(ID) -- fetch list of properties in the group
function Sql:props_get(id)
	id = tonumber(id);
	if not id then
		self.err = "Sql:props_get:: id is not integer";
		return nil, self.err;
	end;
	if self.con == nil then self:connect() end;
	if not self.con then return nil end;
	local que = 'SELECT ' ..
		'`id`, `type`, `caption`, `list`, `default` ' ..
		'FROM `properties` ' ..
		'WHERE `group` = ' .. id ..
		' ORDER BY `id`';
	local cur;
	cur, self.err = self.con:execute(que);
	return cur;
end;
-- }}} Sql:props_get

-- {{{ Sql:group_del(id) -- delete the group by ID
function Sql:group_del(id)
	id = tonumber(id);
	if not id then
		self.err = "No group name specified";
		return nil, self.err;
	end;
	if self.con == nil then self:connect() end;
	if not self.con then return nil end;
	local que = 'DELETE FROM `prop_groups` WHERE `id` = ' .. id;
	local cur;
	cur, self.err = self.con:execute(que);
	if not cur then return nil, self.err end;
	local que = 'DELETE FROM `properties` WHERE `group` = ' .. id;
	cur, self.err = self.con:execute(que);
	return cur, self.err;
end;
-- }}} Sql:group_del

-- {{{ Sql:group_add(name) -- add a new group with a specified name
function Sql:group_add(name)
	if not name then return nil, "No group name specified" end;
	if self.con == nil then self:connect() end;
	if not self.con then return nil end;
	local que = 'INSERT INTO `prop_groups` ' ..
		'(`name`) VALUES (' .. self:escape(name) .. ')';
	local cur;
	cur, self.err = self.con:execute(que);
	return cur;
end;
-- }}} Sql:group_add

-- {{{ Sql:show() -- show table content
function Sql:show()
	local t = self.table;
	if (self.struct[t] == nil) then return false end;
	if self.con == nil then self:connect() end;
	local s;
	if (t == 'urls') then
		s = 'SELECT ' ..
			'`urls`.`id`,' ..
			'`groups`.`name`,' ..
			'`urls`.`scheme`,' ..
			'`urls`..`delim`,' ..
			'`urls`..`userinfo`,' ..
			'`urls`..`regname`,' ..
			'`urls`..`path`,' ..
			'`urls`..`query`,' ..
			'`urls`..`fragment`,' ..
			'`urls`..`descr`' ..
			' FROM `urls` ' ..
			' LEFT JOIN `groups` ' ..
			' ON `urls`.`group` = `groups`.`id`';
		if #self.group > 0 then
			s = s .. ' WHERE ' ..
				'`groups`.`name` LIKE ' ..
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
		if t == 'urls' then
			s = '"' .. r["name"] .. '"\t' .. implode_uri(r);
		elseif t == 'groups' then
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
	if self.con == nil then self:connect() end;
	local s;
	for k, v in pairs(self.struct) do
		s = "CREATE TABLE IF NOT EXISTS " ..
			self:escape(k) ..
			" (";
		for i, j in pairs(v) do
			s = s .. "`" .. i .. "` " .. j .. ",";
		end;
		s = s .. 'PRIMARY KEY (`id` AUTOINCREMENT) )';
		self.cur, self.err = self.con:execute(s);
		if not self.cur then return nil end;
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
	id = tonumber(id);
	if not id then self.err = "Invalid Id" ; return false end;
	group = tonumber(group);
	if not group then
		group = "";
	else
		group = ",`group` = " .. group;
	end;
	local url = parse_uri(url);
	local s = 'UPDATE `urls` ' ..
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
		local s = 'DELETE FROM `groups` ' ..
			' WHERE `url` = ' .. id;
		self.cur, self.err = self.con:execute(s);
		for k, v in ipairs(prop) do
			if v[1] ~= "" then
				s = 'INSERT INTO `groups` ' ..
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
	if not s or unistring.u8_check(s, unistring.u8_strlen(s)) then
		return '""';
	end;
	return '"' .. string.gsub(s, '"', '""') .. '"';
end;
-- }}} Sql:escape(s)

-- }}} Sql object
--]==]

return {
	["Sqlite3"] = Sqlite3,
};
-- vim: set foldmethod=marker:
