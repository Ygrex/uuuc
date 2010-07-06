#!/usr/bin/env sh

# Take a screenshot of a specified WEB-page
#
# Requirements:
#	wget
#	cutycapt
#	mkdir -p
#	echo

[ -z "$1" ] && {
	echo "USAGE: ""$0"" any-url [out-file]"
	exit 1
}

# check availability of all necessary utilities
for i in "wget" "mkdir" "sed" "cutycapt" ; do
	env $i --version >/dev/null 2>&1
	[ $? -eq 127 ] && {
		echo "Cannot find $i"
		exit 127
	}
done;

TEMPDIR=${HOME}/.local/share/uuuc/html
mkdir -p "$TEMPDIR"
OUTFILE="${TEMPDIR}"/wget.out
cd "${TEMPDIR}" && wget -nv -o "${OUTFILE}" -k -p -nH -E -l 0 "$1" || {
	echo "Unable to create directory: ""${TEMPDIR}"
	exit 2
}
FILE="$(sed -nr 's@\?@%3F@g; s@^(([^ \t]+) ){5}"(.*)" \[[0-9]+\]$@\3@p;q' "${OUTFILE}")"

[ -z "${FILE}" ] && {
	cat <$OUTFILE >&2
	exit 1
}

[ -n "$2" ] && OUTFILE="$2" || OUTFILE="${TEMPDIR}"/uuuc.png
cutycapt --url="${FILE}" --out="${OUTFILE}" >/dev/null 2>&1

echo "${OUTFILE}"

