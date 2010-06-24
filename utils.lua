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
function parse_uri(uri)
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
		")" ..
		"(:(?<port>[0-9]+))?" ..
		"(?<path>/[" .. pchar .. "][/" .. pchar .. "]*)?" ..
		"(\\?(?<query>[/?" .. pchar .. "]+))?" ..
		"(#(?<fragment>[/?" .. pchar .. "]+))" ..
		"$");
	local ret = {re:exec(uri)};
	local l = #ret;
	if l > 0 then return ret[l] end;
	ret = { re:exec(encode_uri(uri)) };
	local l = #ret;
	if l < 1 then return nil end;
	ret = ret[l];
	for k, v in pairs(ret) do ret[k] = decode_uri(v) end;
	return ret;
end;
-- }}} parse_uri(uri)

-- {{{ encode_uri(uri)
-- RFC 3986
function encode_uri(uri)
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
function decode_uri(uri)
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

-- vim: set foldmethod=marker:
