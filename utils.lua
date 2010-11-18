-- {{{ parse_uri(uri) -- parse string as URI following RFC 3986
--	return table with following associative fields:
--	scheme
--	delim (either "//" or empty)
--	userinfo
--	host
--		ipv4
--		ipv6
--		ipvfuture
--	regname
--	port
--	path
--	query
--	fragment
local function parse_uri(uri)
	local sub_delims = "$&'()*+,;=!";
	local unreserved = "0-9a-zA-Z._~-";
	local pct_encoded = "%a-zA-Z0-9";
	local pchar = ":@" .. sub_delims .. pct_encoded .. unreserved;
	local h16 = "[a-fA-F0-9]{1,4}";
	local re = rex_pcre.new("^(" ..
		"(?<scheme>[a-zA-Z][0-9a-zA-Z+.-]*):)?" ..
		"(?<delim>//)?" ..
		"(" .. -- authority
			"(?<userinfo>" ..
				"[:" ..
					sub_delims ..
					pct_encoded ..
					unreserved ..
				"]+" ..
			")" ..
		"@)?" ..
		"(?<host>" ..
			"(?<ipv4>" ..
				"(" ..
					"[0-9]{1,2}\\." ..
					"|" ..
					"1[0-9]{2}\\." ..
					"|" ..
					"2[0-4][0-9]\\." ..
					"|" ..
					"25[0-5]\\." ..
				"){3}" ..
				"(" ..
					"[0-9]{1,2}" ..
					"|" ..
					"1[0-9]{2}" ..
					"|" ..
					"2[0-4][0-9]" ..
					"|" ..
					"25[0-5]" ..
				")" ..
			")" ..
			"|" ..
			"(?<ipv6>" ..
				"\\[(" ..
					"(" .. h16 .. ":){7}" .. h16 ..
					"|" ..
					"::(" .. h16 .. ":){0,6}" .. h16 ..
					"|" ..
					h16 .. "::(" .. h16 .. ":){5}" ..
						h16 ..
					"|" ..
					"(" .. h16 .. ":){1,2}:" ..
						"(" .. h16 .. ":){4}" ..
						h16 ..
					"|" ..
					"(" .. h16 .. ":){1,3}:" ..
						"(" .. h16 .. ":){3}" ..
						h16 ..
					"|" ..
					"(" .. h16 .. ":){1,4}:" ..
						"(" .. h16 .. ":){2}" ..
						h16 ..
					"|" ..
					"(" .. h16 .. ":){1,5}:" ..
						h16 .. ":" .. h16 ..
					"|" ..
					"(" .. h16 .. ":){1,6}:" .. h16 ..
				")\\]" ..
			")" ..
			"|" ..
			"(?<ipvfuture>" ..
				"\\[v[0-9a-fA-F]+\\." ..
				"[:" ..
					sub_delims ..
					unreserved ..
				"]+" ..
				"\\]" ..
			")" ..
			"|" ..
			"(?<regname>" ..
				"[" ..
					pct_encoded ..
					sub_delims ..
					unreserved ..
				"]+" ..
			")" ..
		")?" ..
		"(:(?<port>[0-9]+))?" ..
		"(?<path>/[" .. pchar .. "][/" .. pchar .. "]*)?" ..
		"(\\?(?<query>[/?" .. pchar .. "]+))?" ..
		"(#(?<fragment>[/?" .. pchar .. "]+))?" ..
		"$");
	local ret = {re:exec(uri)};
	local l = #ret;
	if l > 0 then
		for k, v in pairs(ret[l]) do
			if not v then ret[l][k] = "" end;
		end;
		return ret[l];
	end;
	ret = { re:exec(encode_uri(uri)) };
	local l = #ret;
	if l < 1 then return nil end;
	ret = ret[l];
	for k, v in pairs(ret) do
		if not v then
			ret[k] = "";
		else
			ret[k] = decode_uri(v);
		end;
	end;
	return ret;
end;
-- }}} parse_uri(uri)

-- {{{ encode_uri(uri)
-- RFC 3986
local function encode_uri(uri)
	local unreserved = "0-9a-zA-Z._~-";
	local sub_delims = "$&'()*+,;=!";
	local gen_delims = ":/?#@%[%]";
	uri = string.gsub(
		uri,
		"[^" .. gen_delims .. sub_delims .. unreserved .. "]",
		function(a)
			return "%" .. string.format(
				"%02X",
				string.byte(a, 1, 1)
			);
		end
	);
	return uri;
end;
-- }}} encode_uri(uri)

-- {{{ decode_uri(uri)
-- RFC 3986
local function decode_uri(uri)
	local function decode(uri)
		uri = string.gsub(
			uri,
			"%%%x%x",
			function(a)
				return string.char("0x" .. a:sub(2, 3));
			end
		);
		return uri;
	end;
	local e, s = pcall(decode, uri);
	if e then return s
	else return uri
	end;
end;
-- }}} decode_uri(uri)

-- {{{ implode_uri(uri) -- return full URI-string from the specified table
local function implode_uri(uri)
	local header = {
		"scheme", "delim", "userinfo",
		"regname", "path", "query",
		"fragment",
	};
	for i = 1, #header, 1 do
		local k = header[i];
		if type(uri[k]) ~= "string" then
			uri[k] = nil;
		end;
	end;
	local s = "";
	if uri["scheme"] then
		s = uri["scheme"] .. ":";
		if uri["delim"] then
			s = s .. uri["delim"];
		end;
	end;
	if uri["userinfo"] then
		s = s .. uri["userinfo"] .. "@";
	end;
	if uri["regname"] then s = s .. uri["regname"] end;
	if uri["path"] then s = s .. uri["path"] end;
	if uri["query"] then s = s .. "?" .. uri["query"] end;
	if uri["fragment"] then s = s .. "#" .. uri["fragment"] end;
	return s;
end;
-- }}} implode_uri(uri)

return {
	["parse_uri"]	= parse_uri,
	["encode_uri"]	= encode_uri,
	["decode_uri"]	= decode_uri,
	["implode_uri"]	= implode_uri,
};

-- vim: set foldmethod=marker:
