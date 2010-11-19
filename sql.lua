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
{
	"changes",
	dlffi.ffi_type_sint,
	{ dlffi.ffi_type_pointer }
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
{
	"last_insert_rowid",
	dlffi.ffi_type_sint64,
	{ dlffi.ffi_type_pointer }
},
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

-- {{{ includes
local utils = require("utils");
assert(type(utils) == "table");
-- }}} includes

-- {{{ Sqlite3 -- Sqlite3 class
assert(type(TBL) == "table", "TBL is not specified");

local Sqlite3 = {
	["_type"] = "object",	-- for a correct work of Dlffi methods
	["tbl"] = {		-- list of interesting tables
		["url"]		= tostring(TBL.url),
		["group"]	= tostring(TBL.group),
		["prop"]	= tostring(TBL.prop),
		["item"]	= tostring(TBL.item),
		["val"]		= tostring(TBL.val),
	},
	["struct"] = {
		-- URIs
		["url"]		= {
				["id"]		= "INTEGER",
				["parent"]	= "INTEGER DEFAULT NULL",
				["unfold"]	= "INTEGER DEFAULT 0",
				["scheme"]	= "VARCHAR(256)",
				["delim"]	= "VARCHAR(256)",
				["userinfo"]	= "VARCHAR(1024)",
				["regname"]	= "VARCHAR(256)",
				["path"]	= "VARCHAR(4096)",
				["query"]	= "VARCHAR(4096)",
				["fragment"]	= "VARCHAR(4096)",
				-- group of URI's properties
				["group"]	= "INTEGER DEFAULT NULL",
				-- URI's comments
				["misc"]	= "VARCHAR(65536)",
			},
		-- properties groups
		["group"]	= {
				["id"]		= "INTEGER",
				["name"]	=
					"VARCHAR(128) DEFAULT 'New Group'",
			},
		-- properties' types
		["prop"]	= {
				["id"]		= "INTEGER",
				["group"]	= "INTEGER",
				-- type indicator
				--	number
				--	string
				--	date
				--	list
				["type"]	= "VARCHAR(128)",
				["name"]	= "VARCHAR(128)",
				-- default value
				["default"]	= "VARCHAR(65536)",
			},
		-- items for properties of list type
		["item"]	= {
				["id"]		= "INTEGER",
				["prop"]	= "INTEGER",
				["name"]	= "VARCHAR(256)",
			},
		-- properties' values
		["val"]	= {
				["id"]		= "INTEGER",
				["prop"]	= "INTEGER",
				["url"]		= "INTEGER",
				-- untyped value
				["value"]	= "VARCHAR(65536)",
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
				),
				string.format(
					[[FOREIGN KEY(`group`) ]] ..
					[[REFERENCES `%s`(`id`) ]] ..
					[[ON DELETE SET DEFAULT ]] ..
					[[ON UPDATE CASCADE ]] ..
					[[DEFERRABLE INITIALLY DEFERRED ]],
					TBL.group
				),
			},
		["group"]	= {
				"PRIMARY KEY (`id` AUTOINCREMENT)",
			},
		["prop"]	= {
				"PRIMARY KEY (`id` AUTOINCREMENT)",
				string.format(
					[[FOREIGN KEY(`group`) ]] ..
					[[REFERENCES `%s`(`id`) ]] ..
					[[ON DELETE CASCADE ]] ..
					[[ON UPDATE CASCADE ]] ..
					[[DEFERRABLE INITIALLY DEFERRED ]],
					TBL.group
				),
			},
		["item"]	= {
				"PRIMARY KEY (`id` AUTOINCREMENT)",
				string.format(
					[[FOREIGN KEY(`prop`) ]] ..
					[[REFERENCES `%s`(`id`) ]] ..
					[[ON DELETE CASCADE ]] ..
					[[ON UPDATE CASCADE ]] ..
					[[DEFERRABLE INITIALLY DEFERRED ]],
					TBL.prop
				),
			},
		["val"]		= {
				"PRIMARY KEY (`id` AUTOINCREMENT)",
				string.format(
					[[FOREIGN KEY(`prop`) ]] ..
					[[REFERENCES `%s`(`id`) ]] ..
					[[ON DELETE CASCADE ]] ..
					[[ON UPDATE CASCADE ]] ..
					[[DEFERRABLE INITIALLY DEFERRED ]],
					TBL.prop
				),
				string.format(
					[[FOREIGN KEY(`url`) ]] ..
					[[REFERENCES `%s`(`id`) ]] ..
					[[ON DELETE CASCADE ]] ..
					[[ON UPDATE CASCADE ]] ..
					[[DEFERRABLE INITIALLY DEFERRED ]],
					TBL.url
				),
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
		{Sqlite3, sqlite3},
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
	-- {{{ create tables
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
	-- }}} create tables
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

-- {{{ Sqlite3:insert_uri(argv)
function Sqlite3:insert_uri(argv)
	local col = {};
	local val = {};
	for k, v in pairs(argv) do
		local t = self.struct.url[k];
		if t then
			table.insert(col, string.format("`%s`", k));
			-- FIXME escape fields here
			if v == dlffi.NULL then
				table.insert(val, "NULL");
			else
				table.insert(val, string.format("'%s'", v));
			end;
		end;
	end;
	if #col < 1 then
		return nil, "Sqlite3:insert_uri():: invalid arguments";
	end;
	local que = string.format(
		[[INSERT INTO `%s` (%s) VALUES (%s)]],
		self.tbl.url,
		table.concat(col, ","),
		table.concat(val, ",")
	);
	local r, e = self:query(que);
	if not r then return nil, e end;
	local r, e = self:last_insert_rowid();
	return r;
end;
-- }}} Sqlite3:insert_uri

-- {{{ Sqlite3:fetch_uris(parent) -- return URI list
function Sqlite3:fetch_uris(parent)
	if not parent then
		parent = "IS NULL";
	elseif parent == dlffi.NULL then
		parent = "IS NULL";
	else
		parent = "= " .. tostring(parent);
	end;
	local que = string.format(
[[SELECT `id`,`misc`,`unfold` FROM `%s` WHERE `parent` %s ORDER BY `misc`]],
		self.tbl.url,
		tostring(parent)
	);
	return self:query(que);
end;
-- }}} Sqlite3:fetch_uris

-- {{{ Sqlite3:fetch_groups() -- return list of groups
function Sqlite3:fetch_groups()
	local que = string.format(
		[[SELECT `id`,`name` FROM `%s` ORDER BY `name`]],
		self.tbl.group
	);
	return self:query(que);
end;
-- }}} Sqlite3:fetch_groups

-- {{{ Sqlite3:fetch_uri(id) -- return URI info
function Sqlite3:fetch_uri(id)
	id = tonumber(id);
	if not id then return nil, "fetch_uri(): Invalid ID" end;
	local que = string.format(
		[[SELECT %s%s%s FROM `%s` WHERE `id` = %d]],
		"`id`,`misc`,`group`,",
			"`scheme`,`delim`,`userinfo`,",
			"`regname`,`path`,`query`,`fragment`",
		self.tbl.url,
		id
	);
	local row = self:query(que);
	if type(row) ~= "table" then return nil end;
	row = row[1];
	row = {
		["id"]		= row[1],
		["misc"]	= row[2],
		["group"]	= row[3],
		["scheme"]	= row[4],
		["delim"]	= row[5],
		["userinfo"]	= row[6],
		["regname"]	= row[7],
		["path"]	= row[8],
		["query"]	= row[9],
		["fragment"]	= row[10],
	};
	-- FIXME dummy URI
	row["uri"] = row["path"];
	return row;
end;
-- }}} Sqlite3:fetch_uri

-- {{{ Sqlite3:fetch_list(...) - retreive table of records from DB
--	tbl	- table name to read from
--	fields	- array of fields to read
--	id	- field name to filter records
--	val	- required value of filtering field
--	assoc	- compose dictionary
function Sqlite3:fetch_list(tbl, fields, id, val, assoc)
	val = tonumber(val);
	if not val then
		return nil, "Sqlite3:fetch_list(): invalid filtering value";
	end;
	local que = {};
	-- fields to SELECT from DB
	for i = 1, #fields, 1 do
		table.insert(
			que,
			string.format("`%s`.`%s`", tbl, fields[i])
		);
	end;
	-- compose a query
	que = string.format(
		[[SELECT %s FROM `%s` WHERE `%s` = %d]],
		table.concat(que, ","),
		tbl, -- FROM
		id, val -- WHERE
	);
	if not assoc then return self:query(que) end;
	local r, e = self:query(que);
	if not r then return nil, e end;
	-- add dictionary keys to each fetched record
	for i = 1, #r, 1 do
		local v = r[i];
		for j = 1, #fields, 1 do
			v[fields[j]] = v[j];
		end;
	end;
	return r;
end;
-- }}} Sqlite3:fetch_list()

-- {{{ get_assoc(...) - add associative keys to array table
--	fields	- array of keys
--	tbl	- data array (table)
--	e	- error string to return if something wrong
local function get_assoc(fields, tbl, e)
	if not tbl then return nil, e end;
	for i = 1, #tbl, 1 do
		local v = tbl[i];
		for j = 1, #fields, 1 do
			v[fields[j]] = v[j];
		end;
	end;
	return tbl;
end;
-- }}} get_assoc()

-- {{{ Sqlite3:fetch_props(...) -- return properties of the group
--	group	- group id
--	uri	- URI id
function Sqlite3:fetch_props(group, uri)
	group = tonumber(group);
	if not group then
		return nil, "Sqlite3:fetch_props(): invalid group"
	end;
	uri = tonumber(uri);
	if not uri then
		return nil, "Sqlite3:fetch_props(): invalid URI"
	end;
	local prop = self.tbl.prop;
	local val = self.tbl.val;
	local que = string.format(
	"SELECT " ..
		"`%s`.`id`, `%s`.`name`, `%s`.`type`, `%s`.`default`, " ..
		"`%s`.`value` " ..
	"FROM `%s` " ..
	"LEFT JOIN `%s` " ..
		"ON `%s`.`id` = `%s`.`prop` " ..
		"AND `%s`.`url` = %d " ..
	"WHERE " ..
		"`%s`.`group` = %d "
	,
	prop, prop, prop, prop,	-- SELECT
	val,	-- SELECT
	prop,	-- FROM
	val,	-- LEFT JOIN
	prop, val,	-- ON
	val, uri,	-- AND
	prop, group	-- WHERE
	);
	que = self:query(que);
	if true then
		return get_assoc(
			{"id", "name", "type", "default", "value"},
			que
		);
	end;
	return self:fetch_list(
		self.tbl.prop,
		{"id", "name", "type", "default"},
		"group",
		group,
		true
	);
end;
-- }}} Sqlite3:fetch_props

-- {{{ Sqlite3:fetch_items(...)
--	prop - list property id
function Sqlite3:fetch_items(prop)
	return self:fetch_list(
		self.tbl.item,
		{"id", "name"},
		"prop", prop
	);
end;
-- }}} Sqlite3:fetch_items()

-- {{{ Sqlite3:unfold_uri(id, unfold) -- unfold/collapse the URI
function Sqlite3:unfold_uri(id, unfold)
	id = tonumber(id);
	if not id then return nil, "unfold_uri(): invalid ID" end;
	if unfold then unfold = 1 else unfold = 0 end;
	local que = string.format(
		"UPDATE `%s` SET `unfold` = %d WHERE `id` = %d",
		self.tbl.url, unfold, id
	);
	return self:query(que);
end;
-- }}} Sqlite3:unfold_uri

-- {{{ Sqlite3:write_value(...) - write value for the URI's property
--	uri	- URI ID
--	prop	- prop ID
--	val	- value
function Sqlite3:write_value(uri, prop, val)
	-- try to update
	local que = string.format(
		[[UPDATE `%s` SET `value` = '%s' ]] ..
		[[WHERE `prop` = %d AND `url` = %d]],
		self.tbl.val, tostring(val),
		prop, uri
	);
	local r, e = self:query(que);
	if e then return nil, "update: " .. tostring(e) end;
	r, e = self:changes();
	r = tonumber(r);
	if not r then
		return nil, "sqlite3_changes(): " .. tostring(e);
	end;
	if r > 0 then return true end;
	-- try to insert new value
	que = string.format(
		[[INSERT INTO `%s` ]] ..
		[[(`prop`, `url`, `value`) ]] ..
		[[VALUES (%d, %d, '%s')]],
		self.tbl.val,
		prop, uri, val
	);
	r, e = self:query(que);
	if e then return nil, "insert: " .. tostring(e) end;
	r, e = self:changes();
	return r == 1, e;
end;
-- }}} Sqlite3:write_value()

-- {{{ Sqlite3:write_uri(...) - update URI info
--	id	- URI ID
--	uri	- URI text representation
--	misc	- comments
--	group	- URI group ID
function Sqlite3:write_uri(id, uri, misc, group)
	group = tonumber(group);
	if not group then
		group = "NULL";
	elseif group < 0 then
		group = "NULL";
	end;
	id = tonumber(id);
	-- update URI information
	local que = string.format(
		[[UPDATE `%s` SET ]] ..
			[[`path` = '%s', ]] ..
			[[`misc` = '%s', ]] ..
			[[`group` = %s ]] ..
		[[WHERE `id` = %d]],
		self.tbl.url,
		tostring(uri), -- path (FIXME dummy)
		tostring(misc),
		group,
		id -- WHERE
	);
	local r, e = self:query(que);
	if not r then
		return nil, "UPDATE: " .. tostring(e);
	end;
	-- delete stale property values
	que = string.format(
		[[DELETE FROM `%s` ]] ..
		[[WHERE `id` IN (]] ..
			[[SELECT `%s`.`id` FROM `%s` ]] ..
			[[LEFT JOIN `%s` ]] ..
			[[ON `%s`.`prop` = `%s`.`id` ]] ..
			[[WHERE `%s`.`url` = %d ]] ..
			[[AND `%s`.`group` != %s]] ..
		[[)]],
		self.tbl.val, -- DELETE FROM
		self.tbl.val, self.tbl.val, -- SELECT FROM
		self.tbl.prop, -- LEFT JOIN
		self.tbl.val, self.tbl.prop, -- ON
		self.tbl.val, id, -- WHERE
		self.tbl.prop, group -- AND
	);
	r, e = self:query(que);
	if not r then
		return nil, "DELETE: " .. tostring(e);
	end;
	return true;
end;
-- }}} Sqlite3:write_uri()

return {
	["Sqlite3"] = Sqlite3,
};
-- vim: set foldmethod=marker:
