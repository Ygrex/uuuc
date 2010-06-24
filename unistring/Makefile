all: compile
LUA_CFLAGS=-I/usr/include/lua5.1 -O2 -fpic
LUA_LDFLAGS=-O -shared -fpic

compile: lua_utf8 test

lua_utf8: liblua_unistring.c
	$(CC) $(CFLAGS) $(LUA_CFLAGS) -c liblua_unistring.c -o liblua_unistring.o
	$(CC) $(CFLAGS) $(LUA_LDFLAGS) -lunistring -o liblua_unistring.so liblua_unistring.o

test: test.c
	$(CC) $(CFLAGS) -lunistring test.c -o test

clean:
	rm liblua_unistring.o

distclean:
	rm liblua_unistring.so
	rm test
