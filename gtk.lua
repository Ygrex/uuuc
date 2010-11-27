local dlffi = require("dlffi");
assert(type(dlffi) == "table", "Error loading Dlffi module");

local function fundamental_shift(n)
	return n * 4;
end;

local gtk = {
	["G_SPAWN_LEAVE_DESCRIPTORS_OPEN"]	= 1,
	["G_SPAWN_DO_NOT_REAP_CHILD"]		= 2,
	["G_SPAWN_SEARCH_PATH"]			= 4,
	["G_SPAWN_STDOUT_TO_DEV_NULL"]		= 8,
	["G_SPAWN_STDERR_TO_DEV_NULL"]		= 16,
	["G_SPAWN_CHILD_INHERITS_STDIN"]	= 32,
	["G_SPAWN_FILE_AND_ARGV_ZERO"]		= 64,
	["G_TYPE_INT"]		= fundamental_shift(6),
	["G_TYPE_STRING"]	= fundamental_shift(16),
	["G_TYPE_POINTER"]	= fundamental_shift(17),
	["G_TYPE_VARIANT"]	= fundamental_shift(21),
	["DIALOG_MODAL"]			= 1,
	["DIALOG_DESTROY_WITH_PARENT"]		= 2,
	["EXPAND"]		= 1,
	["SHRINK"]		= 2,
	["FILL"]		= 4,
	["FILE_CHOOSER_ACTION_OPEN"]		= 0,
	["FILE_CHOOSER_ACTION_SAVE"]		= 1,
	["FILE_CHOOSER_ACTION_SELECT_FOLDER"]	= 2,
	["FILE_CHOOSER_ACTION_CREATE_FOLDER"]	= 3,
	["SELECTION_SINGLE"]	= 1,
	["STOCK_CANCEL"]	= "gtk-cancel",
	["STOCK_OK"]		= "gtk-ok",
	["STOCK_OPEN"]		= "gtk-open",
	["RESPONSE_CANCEL"]	= -6,
	["RESPONSE_ACCEPT"]	= -3,
	["WRAP_NONE"]		= 0,
	["WRAP_CHAR"]		= 1,
	["WRAP_WORD"]		= 2,
	["WRAP_WORD_CHAR"]	= 3,
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
typedef["gboolean"]		= dlffi.ffi_type_sint;
typedef["gint"]			= dlffi.ffi_type_sint;
typedef["gint8"]		= dlffi.ffi_type_sint8;
typedef["guint"]		= dlffi.ffi_type_uint;
typedef["guint32"]		= dlffi.ffi_type_uint32;
typedef["guint64"]		= dlffi.ffi_type_uint64;
typedef["gulong"]		= dlffi.ffi_type_ulong;
typedef["gdouble"]		= dlffi.ffi_type_double;
typedef["GQuark"]		= dlffi.ffi_type_uint32;
typedef["GType"]		= dlffi.ffi_type_size_t;
typedef["GdkEventType"]		= dlffi.ffi_type_sint;
typedef["GConnectFlags"]	= dlffi.ffi_type_sint;
typedef["GtkAttachOptions"]	= dlffi.ffi_type_sint;
typedef["GtkDialogFlags"]	= dlffi.ffi_type_sint;
typedef["GtkFileChooserAction"]	= dlffi.ffi_type_sint;
typedef["GtkResponseType"]	= dlffi.ffi_type_sint;
typedef["GtkSelectionMode"]	= dlffi.ffi_type_sint;
typedef["GtkWrapMode"]		= dlffi.ffi_type_sint;
typedef["GSpawnFlags"]		= dlffi.ffi_type_sint;
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
typedef["GtkTextIter"] = {
	dlffi.ffi_type_pointer,	-- dummy1
	dlffi.ffi_type_pointer,	-- dummy2
	typedef.gint,		-- dummy3
	typedef.gint,		-- dummy4
	typedef.gint,		-- dummy5
	typedef.gint,		-- dummy6
	typedef.gint,		-- dummy7
	typedef.gint,		-- dummy8
	dlffi.ffi_type_pointer,	-- dummy9
	dlffi.ffi_type_pointer,	-- dummy10
	typedef.gint,		-- dummy11
	typedef.gint,		-- dummy12
	typedef.gint,		-- dummy13
	dlffi.ffi_type_pointer,	-- dummy14
};
assert(typedef["GtkTextIter"]);
typedef["GValue"] = {
	typedef.GType,
	typedef.guint64,
	typedef.guint64,
};
assert(typedef["GValue"]);
-- }}} GTK+ typedef

-- {{{ library header
--	sequence order is highly important or get_object() will fail
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
-- {{{ gtk_cell_renderer_pixbuf
{
	{
		"new",
		dlffi.ffi_type_pointer,
		{ },
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_cell_renderer_pixbuf",
},
-- }}} gtk_cell_renderer_pixbuf
-- {{{ gtk_combo_box_entry
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"new_with_model",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
			typedef.gint,
		},
		["_gen"] = true,
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
		["_gen"] = true,
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
	{
		"get_active_iter",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"get_active_text",
		dlffi.ffi_type_pointer,
		{
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
		"get_text",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
		},
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
		{ ["ret"] = typedef.gboolean, 2 },
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"set_select_function",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,
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
		"newv",
		dlffi.ffi_type_pointer,
		{
			typedef.gint,
			dlffi.ffi_type_pointer,
		},
		["_gen"] = true,
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
-- {{{ gtk_tree_model
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
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
		{ ret = dlffi.ffi_type_void, 4 },
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			typedef.gint,
			typedef["GValue"],
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
	{
		"new",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
		},
		["_gen"] = true,
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	{
		"get_text",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			typedef.gboolean,
		},
	},
	{
		"get_bounds",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_text_buffer",
},
-- }}} gtk_text_buffer
-- {{{ gtk_tool_button
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
	["_prefix"] = "gtk_tool_button",
},
-- }}} gtk_tool_button
-- {{{ gtk_text_view
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"new_with_buffer",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
		["_gen"] = true,
	},
	{
		"get_buffer",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
		["_gen"] = true,
	},
	{
		"set_wrap_mode",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer, typedef.GtkWrapMode },
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_text_view",
},
-- }}} gtk_text_view
-- {{{ gtk_tree_path
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"to_string",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
	},
	{
		"up",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
	},
	{
		"copy",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
	},
	{
		"get_depth",
		typedef.gint,
		{ dlffi.ffi_type_pointer },
	},
	{
		"compare",
		typedef.gint,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer },
	},
	{
		"free",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer },
	},
	-- prefix for any symbol name in the library
	["_prefix"] = "gtk_tree_path",
},
-- }}} gtk_tree_path
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
		["_gen"] = true,
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
-- {{{ gtk_file_chooser_dialog
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"new",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			typedef.GtkFileChooserAction,
			dlffi.ffi_type_pointer,
			typedef.GtkResponseType,
			dlffi.ffi_type_pointer,
			typedef.GtkResponseType,
			dlffi.ffi_type_pointer,
		},
		["_gen"] = true,
	},
	["_inherit"] = {
		"gtk_file_chooser",
		"gtk_widget",
		"g_signal",
	},
	["_prefix"] = "gtk_file_chooser_dialog",
},
-- }}} gtk_file_chooser_dialog
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
-- {{{ gtk_file_chooser
{
	{
		"get_uri",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
		},
		
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	["_prefix"] = "gtk_file_chooser",
},
-- }}} gtk_file_chooser
-- {{{ gtk_dialog
{
	{
		"get_type",
		typedef.GType,
		{ },
	},
	{
		"run",
		typedef.gint,
		{
			dlffi.ffi_type_pointer,
		},
		
	},
	{
		"new_with_buttons",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,		-- title
			dlffi.ffi_type_pointer,		-- parent
			typedef["GtkDialogFlags"],	-- flags
			dlffi.ffi_type_pointer,		-- first_button_text
			typedef["GtkResponseType"],	-- first response
			dlffi.ffi_type_pointer,		-- second text
			typedef["GtkResponseType"],	-- second response
			dlffi.ffi_type_pointer,		-- NULL
		},
		["_gen"] = "gtk_dialog",
	},
	["_inherit"] = {
		"gtk_widget",
		"g_signal",
	},
	["_prefix"] = "gtk_dialog",
},
-- }}} gtk_dialog
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
		"value_set_pointer",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer },
	},
	{
		"value_set_pointer",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer },
	},
	{
		"value_take_object",
		dlffi.ffi_type_void,
		{ dlffi.ffi_type_pointer, dlffi.ffi_type_pointer },
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
	{
		"object_get_data",
		dlffi.ffi_type_pointer,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"object_set_data",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_pointer,
		},
	},
	{
		"object_unref",
		dlffi.ffi_type_void,
		{
			dlffi.ffi_type_pointer,
		},
	},
	{
		"free",
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
-- {{{ gdk
{
	{
		"display_get_default",
		dlffi.ffi_type_pointer,
		{},
	},
	{
		"display_get_default_screen",
		dlffi.ffi_type_pointer,
		{ dlffi.ffi_type_pointer },
	},
	{
		"spawn_on_screen_with_pipes",
		typedef.gboolean,
		{
			dlffi.ffi_type_pointer,	-- screen
			dlffi.ffi_type_pointer,	-- working_directory
			dlffi.ffi_type_pointer,	-- argv
			dlffi.ffi_type_pointer,	-- envp
			typedef.GSpawnFlags,	-- flags
			dlffi.ffi_type_pointer,	-- child_setup
			dlffi.ffi_type_pointer,	-- user_data
			dlffi.ffi_type_pointer,	-- child_pid
			dlffi.ffi_type_pointer,	-- stdin
			dlffi.ffi_type_pointer,	-- stdout
			dlffi.ffi_type_pointer,	-- stderr
			dlffi.ffi_type_pointer,	-- error
		},
	},
	{
		"pixbuf_get_type",
		typedef["GType"],
		{},
	},
	{
		"pixbuf_new_from_file_at_size",
		{ ret = dlffi.ffi_type_pointer, 4 },
		{
			dlffi.ffi_type_pointer,
			dlffi.ffi_type_sint,
			dlffi.ffi_type_sint,
			dlffi.ffi_type_pointer,
		},
	},
	["_prefix"] = "gdk",
},
-- }}} gdk
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
--	o	- GObject instance (userdata)
--	pref	- prefix for functions if you know it
--	Return:
--		Dlffi (table) of the appropriate class
local function get_object(o, pref)
	if not o then
		return nil, "get_object(): invalid object specified";
	end;
	if type(pref) == "string" then
		return dlffi.Dlffi:new(find_inherit(pref), o);
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
-- {{{ wrap_get_object()
local wrap_get_object = function(cfunc, gen)
	return function(...) return get_object(cfunc(...), gen) end;
end;
-- }}} wrap_get_object()

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
			local r, rr;
			for k = 1, #libs, 1 do
				-- try to load symbol from the .SO file
				r, rr = dlffi.load(
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
				r = wrap_get_object(cfunc, k);
				if rr then
					local ccfunc = rr;
					rr = wrap_get_object(ccfunc, k);
				end;
			end;
			-- put the loaded symbol to the header
			_gtk[symbol[1]] = r;
			-- restore symbol name
			symbol[1] = name;
			-- put the loaded symbol to appropriate header part
			if rr then
				-- store single-return function with original
				-- name and it's multi-return counterpart
				-- prefixed with "l_"
				lib[name] = rr;
				lib["l_" .. name] = r;
			else
				lib[name] = r;
			end;
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
					if rr then
						local tail = tail .. "_" .. name;
						head[tail] = rr;
						head["l_" .. tail] = r;
					else
						head[tail .. "_" .. name] = r;
					end;
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

-- {{{ Builder - overrides GtkBuilder
local Builder = { _type = "object" };

-- {{{ Builder:get_object(...) - overrides gtk_builder_get_object
function Builder:get_object(name)
	local o, e = gtk.builder_get_object(self, name);
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
	if not o then return nil, "invalid instance" end;
	if not data then data = dlffi.NULL end;
	return _gtk.g_signal_connect_data(o, sig, hdlr, data, dlffi.NULL, 0);
end;
-- }}} g_signal_connect()

-- {{{ g_value
local g_value = {};

g_value.new = function(gtype)
	local size = dlffi.sizeof(typedef.GValue);
	local e;
	if gtype == false then e = false else e = true end;
	local val;
	val, e = typedef:new("GValue", e);
	if not val then
		return nil, "Pointer init failure: " .. tostring(e);
	end;
	local _, e = _bzero(val, size);
	if e then return nil, e end;
	if gtype ~= false then val:set_gc(_gtk.g_value_unset) end;
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
	-- init some special types
	gtk["GDK_TYPE_PIXBUF"] = _gtk.gdk_pixbuf_get_type();
	return true;
end;
-- }}} init()

-- initialize library
local r, e = init();
if not r then return e end;

return {
	["gtk"] = gtk,
	["g"] = find_header("g"),
	["gdk"] = find_header("gdk"),
	["dlffi"] = dlffi,
	["typedef"] = typedef
};

