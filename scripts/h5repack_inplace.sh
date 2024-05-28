#!/bin/bash

for FILE in "$@" ; do

	echo -n "Repack '$FILE' ... "
	TMPFILE=$( mktemp "${FILE}.repack.XXXX.h5" )
	h5repack -i "$FILE" -o "$TMPFILE" &> /dev/null
	if [ "$?" -ne 0 ] ; then
		rm -f "$TMPFILE"
		echo "Error!"
	else
		mv -f "$TMPFILE" "$FILE"
		echo "OK"
	fi

done


