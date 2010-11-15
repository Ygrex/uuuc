local dlffi = require("dlffi");
assert(type(dlffi) == "table", "Error loading Dlffi module");

local function fundamental_shift(n)
	return n * 4;
end;

local gtk = {
	["SELECTION_SINGLE"]	= 1,
	["G_TYPE_INT"]		= fundamental_shift(6),
	["G_TYPE_STRING"]	= fundamental_shift(16),
	["EXPAND"]		= 1,
	["SHRINK"]		= 2,
	["FILL"]		= 4,
};
local gtk_mt = { __index = gtk };

-- table for gtk+-2.0 libs
local libs = {};

-- {{{ libc calls
local _bzero, e = dlffi.load("libc.so.6", "bzero", dlffi.ffi_type_void,
	{
		dlffi.ffi_type_pointer,
		dlffi.ffi_type_size_t,
	}
);
assert(_bzero, e);
local _free, e = dlffi.load("libc.so.6", "free", dlffi.ffi_type_void,
	{
		dlffi.ffi_type_pointer,
	}
);
assert(_free, e);
-- }}} libc calls

-- {{{ find_libs() -- find GTK+-2.0 libraries to load
local function find_libs()
	-- run pkg-config and catch it's output
	local cmd = "/usr/bin/env pkg-config --libs-only-l 'gtk+-2.0'";
	local pipe = io.popen(cmd);
	local r, e = pipe:read("*l");
	pipe:close();
	assert(r, e);
	-- fetch libraries names from pkg-config's output
	for i in r:gmatch("-l([^%s]+)%s+") do
		table.insert(libs, "lib" .. i .. ".so");
	end;
end;
-- }}} find_libs

-- {{{ GTK+ typedef
local typedef, e = dlffi.Dlffi_t:new();
assert(typedef, e);
rawset(typedef, "gboolean"		, dlffi.ffi_type_sint);
rawset(typedef, "gint"			, dlffi.ffi_type_sint);
rawset(typedef, "gint8"			, dlffi.ffi_type_sint8);
rawset(typedef, "guint"			, dlffi.ffi_type_uint);
rawset(typedef, "guint32"		, dlffi.ffi_type_uint32);
rawset(typedef, "guint64"		, dlffi.ffi_type_uint64);
rawset(typedef, "gulong"		, dlffi.ffi_type_ulong);
rawset(typedef, "gdouble"		, dlffi.ffi_type_double);
rawset(typedef, "GQuark"		, dlffi.ffi_type_uint32);
rawset(typedef, "GType"			, dlffi.ffi_type_size_t);
rawset(typedef, "GdkEventType"		, dlffi.ffi_type_sint);
rawset(typedef, "GConnectFlags"		, dlffi.ffi_type_sint);
rawset(typedef, "GtkSelectionMode"	, dlffi.ffi_type_sint);
rawset(typedef, "GtkAttachOptions"	, dlffi.ffi_type_sint);
typedef["GError"] = { typedef.GQuark, typedef.guint, dlffi.ffi_type_pointer };
assert(typedef["GError"]);
typedef["GdkEventButton"] = {
	typedef.GdkEventType,	-- type
	dlffi.ffi_type_pointer,	-- window
	typedef.gint8,		-- send_event
	typedef.guint32,	-- time
	typedef.gdouble,	-- x
	typedef.gdouble,	-- y
	dlffi.ffi_type_pointer,	-- axes
	typedef.guint,		-- state
	typedef.guint,		-- button
	dlffi.ffi_type_pointer,	-- device
	typedef.gdouble,	-- x_root
	typedef.gdouble,	-- y_root
};
assert(typedef["GdkEventButton"]);
typedef["GtkTreeIter"] = {
	typedef.gint,		-- stamp
	dlffi.ffi_type_pointer,	-- user_data
	dlffi.ffi_type_pointer,	-- user_data2
	dlffi.ffi_type_pointer,	-- user_data3
};
assert(typedef["GtkTreeIter"]);
typedef["GValue"] = {
	typedef.GType,
	typedef.guint64,
	typedef.guint64,
};
assert(typedef["GValue"]);
-- {{{ unwrap() - read value from pointer
--	p - pointer (userdata)
--	t - FFI type of value or string
--	if t of FFI type:
--		reads from pointer sizeof() bytes and return them as value
--	if t is a string:
--		find class of the GObject instance and return a proxy
local unwrap = function(p, t)
	local tp = type(t);
	if tp == "string" then
		return dlffi.Dlffi:new(
			find_inherit(t),
			p
		);
	elseif tp == "userdata" then
		local str, e = dlffi.Dlffi_t:new("str", { t });
		if not str then return nil, e end;
		return dlffi.type_element(p, str["str"], 1);
	else
		return nil, "object type cannot be recognized";
	end;
end;
-- }}} unwrap()
rawset(typedef, "unwrap", unwrap);
-- {{{ wrap() - create pointer to the copy of typed value
local wrap = function(v, t)
	if type(t) ~= "userdata" then
		return nil, "object type cannot be recognized";
	end;
	local str, e = dlffi.Dlffi_t:new("str", {t});
	if not str then return nil, "FFI structure init: " .. tostring(e) end;
	local buf, e = dlffi.dlffi_Pointer(dlffi.sizeof(str["str"]), true);
	if not buf then return nil, "Pointer init: " .. tostring(e) end;
	dlffi.type_element(buf, str["str"], 1, v);
	return buf;
end;
-- }}} wrap()
rawset(typedef, "wrap", wrap);
-- }}} GTK+ typedef

-- {{{ library header
local _gtk = {
-- {{{ gtk
{
	{
		"init_check",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"builder_new",
		dlffi.ffi_type_pointer,
		{}
	},
	{
		"main",
		dlffi.ffi_type_void,
		{}
	},
	{
		"main_quit",
		dlffi.ffi_type_void,
		{}
	},
	{
		"tree_path_free",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer }
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk",
},
-- }}} gtk
-- {{{ gtk_builder
{
	{
		"add_from_file",
		typedef.guint,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"get_object",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"connect_signals",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_builder",
},
-- }}} gtk_builder
-- {{{ gtk_cell_renderer_text
{
	{
		"new",
		dlffi.ffi_type_pointer,
		{ },
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_cell_renderer_text",
},
-- }}} gtk_cell_renderer_text
-- {{{ gtk_combo_box_entry
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	["_inherit"] = {
		"gtk_combo_box",
		"gtk_bin",
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_combo_box_entry",
},
-- }}} gtk_combo_box_entry
-- {{{ gtk_combo_box
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"get_model",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
		},
		["_gen"] = "gtk_tree_model",
	},
	{
		"set_active",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			typedef.gint,
		},
	},
	{
		"set_active_iter",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	["_inherit"] = {
		"gtk_bin",
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_combo_box",
},
-- }}} gtk_combo_box
-- {{{ gtk_entry
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"new",
		dlffi.ffi_type_pointer,
		{ },
		["_gen"] = true,
	},
	{
		"set_text",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_entry",
},
-- }}} gtk_entry
-- {{{ gtk_hpaned
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	["_inherit"] = {
		"gtk_paned",
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_hpaned",
},
-- }}} gtk_hpaned
-- {{{ gtk_label
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"new",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
		["_gen"] = true,
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_label",
},
-- }}} gtk_label
-- {{{ gtk_menu
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"popup",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,	-- menu
			dlffi.ffi_type_pointer,	-- parent_menu_shell
			dlffi.ffi_type_pointer,	-- parent_menu_item
			dlffi.ffi_type_pointer,	-- func
			dlffi.ffi_type_pointer,	-- data
			typedef.guint,		-- button
			typedef.guint32,	-- activate_time
		},
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_menu",
},
-- }}} gtk_menu
-- {{{ gtk_image_menu_item
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_image_menu_item",
},
-- }}} gtk_image_menu_item
-- {{{ gtk_paned
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"set_position",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			typedef.gint
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_paned",
},
-- }}} gtk_paned
-- {{{ gtk_tree_model
{
	{
		"get_iter",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"get_iter_first",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"get_value",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			typedef.gint,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"get_path",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"iter_children",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"iter_next",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_tree_model",
},
-- }}} gtk_tree_model
-- {{{ gtk_tree_selection
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"set_mode",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			typedef.GtkSelectionMode,
		},
	},
	{
		"get_selected",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_tree_selection",
},
-- }}} gtk_tree_selection
-- {{{ gtk_tree_store
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"append",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"set_value",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			typedef.gint,
			dlffi.ffi_type_pointer,
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
		"gtk_tree_model",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_tree_store",
},
-- }}} gtk_tree_store
-- {{{ gtk_list_store
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"append",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"set_value",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			typedef.gint,
			dlffi.ffi_type_pointer,
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
		"gtk_tree_model",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_list_store",
},
-- }}} gtk_list_store
-- {{{ gtk_table
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"resize",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			typedef.guint,
			typedef.guint,
		},
	},
	{
		"attach",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,	-- table
			dlffi.ffi_type_pointer,	-- child
			typedef.guint,
			typedef.guint,
			typedef.guint,
			typedef.guint,
			typedef.GtkAttachOptions,
			typedef.GtkAttachOptions,
			typedef.guint,
			typedef.guint,
		},
	},
	["_inherit"] = {
		"gtk_container",
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_table",
},
-- }}} gtk_table
-- {{{ gtk_text_buffer
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"set_text",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			typedef.gint,
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_text_buffer",
},
-- }}} gtk_text_buffer
-- {{{ gtk_tree_view
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"append_column",
		typedef.gint,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"expand_row",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			typedef.gboolean,
		},
	},
	{
		"collapse_row",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"get_model",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
		},
		["_gen"] = "gtk_tree_model",
	},
	{
		"get_selection",
		typedef.gint,
		{
			dlffi.ffi_type_pointer,
		},
		["_gen"] = "gtk_tree_selection",
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_tree_view",
},
-- }}} gtk_tree_view
-- {{{ gtk_tree_view_column
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"new_with_attributes",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,	-- title
			dlffi.ffi_type_pointer,	-- cell
			dlffi.ffi_type_pointer,	-- attribute
			typedef.gint,		-- column
			dlffi.ffi_type_pointer,	-- NULL
		},
		["_gen"] = "gtk_tree_view_column",
	},
	{
		"set_resizable",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,	-- tree_column
			typedef.gboolean,	-- resizable
		},
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_tree_view_column",
},
-- }}} gtk_tree_view_column
-- {{{ gtk_window
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"get_size",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,	-- window
			dlffi.ffi_type_pointer,	-- width
			dlffi.ffi_type_pointer,	-- height
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_window",
},
-- }}} gtk_window
-- {{{ gtk_bin
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"get_child",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
		["_gen"] = true,
	},
	["_inherit"] = {
		"gtk_container",
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_bin",
},
-- }}} gtk_bin
-- {{{ gtk_container
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"foreach",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_container",
},
-- }}} gtk_container
-- {{{ gtk_widget
{
	{
		"show_all",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer },
	},
	{
		"destroy",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer },
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_widget",
},
-- }}} gtk_widget
-- {{{ g
{
	{
		"type_check_instance_is_a",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			typedef.GType
		},
	},
	{
		"value_init",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer, typedef.GType },
	},
	{
		"type_name",
		dlffi.ffi_type_pointer,
		{ typedef.GType },
	},
	{
		"value_set_string",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer },
	},
	{
		"value_get_string",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
	},
	{
		"value_set_int",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, typedef.gint },
	},
	{
		"value_get_int",
		typedef.gint,
		{ dlffi.ffi_type_pointer },
	},
	{
		"value_unset",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer },
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "g",
},
-- }}} g
-- {{{ g_error
{
	{
		"free",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer },
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "g_error",
},
-- }}} g_error
-- {{{ g_signal
{
	{
		"connect_data",
		typedef.gulong,
		{
			dlffi.ffi_type_pointer,	-- instance
			dlffi.ffi_type_pointer,	-- detailed_signal
			dlffi.ffi_type_pointer,	-- c_handler
			dlffi.ffi_type_pointer,	-- data
			dlffi.ffi_type_pointer,	-- destroy_data
			dlffi.ffi_type_sint,	-- connect_flags
		}
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "g_signal",
},
-- }}} g_signal
};
-- }}} library header

-- {{{ find_header(...) - find appropriate header part by given prefix
local function find_header(prefix)
	for i = 1, #_gtk, 1 do
		local l = _gtk[i];
		if l["_prefix"] == prefix then return l end;
	end;
end;
-- }}} find_header()

-- {{{ find_inherit(...) - return table of all inherrited headers
local function find_inherit(prefix)
	local h = {};
	local main = find_header(prefix);
	if not main then return h end;
	table.insert(h, main);
	local inh = main["_inherit"];
	if not inh then return h end;
	for i = 1, #inh, 1 do
		table.insert(h, find_header(inh[i]));
	end;
	return h;
end;
-- }}} find_inherit()

-- {{{ get_object(...) - construct proxy for the object
--	o - GObject instance (userdata)
--	Return:
--		Dlffi (table) of the appropriate class
local function get_object(o)
	if not o then
		return nil, "get_object(): invalid object specified";
	end;
	-- iterate through all headers
	for i = 1, #_gtk, 1 do
		-- emulate "continue" with dummy "repeat" block
		repeat
		local l = _gtk[i];
		-- headers are tables
		if type(l) ~= "table" then break end;
		-- test GObject instance with get_type()
		local get = l["get_type"];
		if not get then break end;
		-- need know class namespace
		local pref = l["_prefix"];
		if not pref then break end;
		local r, e = _gtk.g_type_check_instance_is_a(
			o, get()
		)
		-- g_type_check_instance_is_a() returns gboolean
		if not tonumber(r) then
			return nil,
				"g_type_check_instance_is_a(): " ..
				tostring(e);
		end;
		if tonumber(r) > 0 then
			-- the instance class is found
			-- wrap the object with proxy
			return dlffi.Dlffi:new(
				find_inherit(pref),
				o
			);
		end;
		until true;
	end;
	return nil, "unknown instance type";
end;
-- }}} get_object

-- {{{ load_libs() -- load GTK+-2.0 symbols defined in header
local function load_libs()
	-- iterate through header libraries
	for i = 1, #_gtk, 1 do
		local lib = _gtk[i];
		local prefix = lib["_prefix"];
		-- iterate through symbols in the library
		for j = 1, #lib, 1 do
			local symbol = lib[j];
			-- append prefix to the symbol name
			local name = symbol[1];
			symbol[1] = prefix .. "_" .. name;
			-- iterate through pkg-config's libraries
			local r, e;
			for k = 1, #libs, 1 do
				-- try to load symbol from the .SO file
				r, e = dlffi.load(
					libs[k],
					unpack(symbol)
				);
				if r then break end;
			end;
			assert(r, "symbol not found: " .. (symbol[1]));
			local k = symbol["_gen"];
			if k then
				-- the method constructs new object
				-- create constructor
				local cfunc = r;
				local wrapper = function(...)
					return get_object(cfunc(...));
				end;
				-- substitue the symbol with proxy
				r = wrapper;
			end;
			-- put the loaded symbol to the header
			_gtk[symbol[1]] = r;
			-- restore symbol name
			symbol[1] = name;
			-- put the loaded symbol to appropriate header part
			lib[name] = r;
			-- split prefix by underscores and store the symbol
			-- to headers of parent namespaces
			local cur = 1;
			repeat
				e, cur = prefix:find("_[^_]+", cur);
				if not e then break end;
				local pref = prefix:sub(1, e - 1);
				local head = find_header(pref);
				if head then
					local tail = prefix:sub(e + 1);
					head[tail .. "_" .. name] = r;
				end;
			until false;
		end;
	end;
end;
-- }}} load_libs()

-- {{{ rtdl_now() - open pkg-config's libs with RTDL_NOW
local function rtdl_now()
	local dlopen, e = dlffi.load(
		"libdl.so.2",
		"dlopen",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_sint }
	);
	assert(dlopen, e);
	for i = 1, #libs, 1 do
		dlopen(libs[i], 2 + 256);
	end;
end;
-- }}} rtdl_now()

-- {{{ gtk.GError(err) -- return error mesage and free GError
--	err - pointer to a GError structure
function gtk.GError(err)
	local s = dlffi.type_element(err, typedef["GError"], 3);
	if not s then return nil, "dlffi.type_element() failed" end;
	s = dlffi.dlffi_Pointer(s):tostring();
	_gtk.g_error_free(err);
	return s;
end;
-- }}} gtk.GError()

-- {{{ Builder - overrides GtkBuilder
local Builder = { _type = "object" };

-- {{{ Builder:get_object(...) - overrides gtk_builder_get_object
function Builder:get_object(name)
	local o, e = gtk.builder_get_object(self._val, name);
	if e then return nil, "get_object(): " .. tostring(e) end;
	return get_object(o);
end;
-- }}} Builder:get_object

-- {{{ gtk.builder_new()
function gtk.builder_new()
	return dlffi.Dlffi:new(
		{ Builder, find_header("gtk_builder"), _gtk },
		_gtk.gtk_builder_new()
	);
end;
-- }}} gtk.builder_new()
-- }}} Builder

-- {{{ g_signal_connect(...) - emulate macro for g_signal_connect
local g_signal_connect = function(o, sig, hdlr, data)
	if type(o) == "table" then o = o["_val"] end;
	if not o then return nil, "invalid instance" end;
	if not data then data = dlffi.NULL end;
	return _gtk.g_signal_connect_data(o, sig, hdlr, data, dlffi.NULL, 0);
end;
-- }}} g_signal_connect()

-- {{{ g_value
local g_value = {};

g_value.new = function(gtype)
	local size = dlffi.sizeof(typedef.GValue);
	local val, e = dlffi.dlffi_Pointer(size, true);
	if not val then
		return nil, "Pointer init failure: " .. tostring(e);
	end;
	local _, e = _bzero(val, size);
	if e then return nil, e end;
	val:set_gc(_gtk.g_value_unset);
	if not gtype then
		-- return uninitialized GValue
		return val;
	end;
	local _, e = _gtk.g_value_init(val, gtype);
	if e then
		return nil, "g_value_init() failure: " .. tostring(e);
	end;
	return val;
end;
-- }}} g_value

-- {{{ init() -- library initialization
local function init()
	-- these functions raise error if anything bad happens, therefore
	-- do not care of return value
	find_libs();
	load_libs();
	-- open libs with RTDL_NOW
	rtdl_now();
	-- gtk object inherits appropriate functions
	local h, e = find_header("gtk");
	assert(h, e);
	for k, v in pairs(h) do
		if k == "_inherit" then v = nil
		elseif k == "_prefix" then v = nil
		elseif gtk[k] then v = nil
		end;
		if v then gtk[k] = v end;
	end;
	-- useful macros
	local h, e = find_header("g_signal");
	assert(h, e);
	h["connect"] = g_signal_connect;
	-- init __call to typedef object
	getmetatable(typedef)["__call"] =
		function(t, ...) return get_object(...) end;
	-- add object for GValue
	find_header("g").value = g_value;
	-- initialize GTK+ now
	local r, e = gtk.init_check(dlffi.NULL, dlffi.NULL);
	assert(not e, e);
	if r == 0 then return nil, "gtk_init_check() returned FALSE" end;
	return true;
end;
-- }}} init()

-- initialize library
local r, e = init();
if not r then return e end;

return {
	["gtk"] = gtk,
	["g"] = find_header("g"),
	["dlffi"] = dlffi,
	["typedef"] = typedef
};

