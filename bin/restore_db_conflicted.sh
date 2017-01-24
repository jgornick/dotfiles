# This script takes a single parameter - a file name following Dropbox "conflicted" file naming format.
# It will then ask you if you want skip, delete, or move it back (restore it) to the original file name.
# The original file name is determined by removing the Drobox conflicted part of the name.
# e.g. "demo-current (Thor's conflicted copy 2014-09-14).png" --> "demo-current.png"
# If you answer 'y' it will perform a 'NIX mv "SOURCE" "TARGET" command.
#
# Typical usage of this script would be something like the following:
# find . -name "*(*'s conflicted copy [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])*" -exec restore_db_conflicted.sh.sh {} \;
# -- Find all the files that look like conflicted copies and run the restore script on them.
# I've used this script a couple of times.  It worked for me.  
# !!! USE AT YOUR OWN RISK !!!

SOURCE=$1
TARGET=`echo $1 | sed -e's/\(.*\)\( (.*)\)\(.*\)/\1\3/'`

echo
if [ "$SOURCE" = "$TARGET" ]; then
	echo "Failed to find conflicted copy filename pattern for \"$TARGET\", skipping."
else
	echo "Conflicted copy \"$SOURCE\""
	echo "(s)kip, (d)elete, (r)estore to \"$TARGET\""
	echo "? (s|d|r)"
	read ans
	if [ "$ans" = "r" ]; then
			echo "MOVING.. \"$SOURCE\" to \"$TARGET\""
			mv "$SOURCE" "$TARGET"
	elif [ "$ans" = "d" ]; then
		echo "DELETING \"$SOURCE\""
		rm -rf "$SOURCE"
	else
		echo "SKIPPING.. \"$SOURCE\""
	fi
fi
