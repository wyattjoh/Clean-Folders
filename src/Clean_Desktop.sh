#!/bin/bash
DATE="$(date +%Y%m%d)"
ARCHIVE="/Users/wyattjohnson/Dropbox/Computers/Macbook-OSX/Desktop"
FOLDER="$ARCHIVE/$DATE"
FROM="/Users/wyattjohnson/Desktop/*"
DEBUG=${1-"OFF"}
X="0"

[[ ! -e "$ARCHIVE" ]] && mkdir "$ARCHIVE"

for file in $FROM
do
	[[ "$file" == "$FROM" ]] && continue
	((X++))
done

[[ "$DEBUG" == "ON" ]] && echo "[debug] X = $X"

[[ "$X" == "0" ]] && growl -nosticky "No Files To Copy! Desktop Clean!"
[[ "$X" == "0" && "$DEBUG" == "OFF" ]] && exit
[[ "$X" == "0" && "$DEBUG" == "ON" ]] && printf "[debug] Now exiting...\n" && exit

[[ ! -e "$FOLDER" ]] && mkdir "$FOLDER"

for file in $FROM
do
	[[ "$file" == "$FROM" ]] && continue
	[[ "$DEBUG" == "ON" ]] && printf "[debug] {file} $file\n"
	[[ "$DEBUG" == "OFF" ]] && mv "$file" "$FOLDER"
done

growl -nosticky "Desktop Cleaning Finished! Desktop Clean!"

