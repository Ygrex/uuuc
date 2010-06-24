#!/usr/bin/env lua

require 'liblua_unistring'

sample = "pókè";
print(string.format(
	"strlen::\t%s:\t%s",
	sample,
	unistring.u8_strlen(sample)
));
print(string.format(
	"mbslen::\t%s:\t%s",
	sample,
	unistring.u8_mbsnlen(
		sample,
		unistring.u8_strlen(sample)
	)
));
print(string.format(
	"strwidth::\t%s:\t%s",
	sample,
	unistring.u8_strwidth(
		sample,
		"UTF-8")
));

