#include <stdio.h>
#include <unistr.h>

main ()
{
	const uint8_t *s = "pókè";
	printf("strlen::\t%s:\t%d\n", s, u8_strlen(s));
	printf("mbslen::\t%s:\t%d\n", s, u8_mbsnlen(s, u8_strlen(s)));
	printf("strwidth::\t%s:\t%d\n", s, u8_strwidth(s, "UTF-8"));
	return 0;
}

