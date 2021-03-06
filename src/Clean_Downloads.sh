#!/bin/bash
DATE="$(date +%Y%m%d)"
ARCHIVE="$HOME/Archives/Downloads"
ARCHIVE_Save="$HOME/Downloads/Archives"
FOLDER="$ARCHIVE/$DATE"
FROM="$HOME/Downloads/*"
DEBUG=${1-"OFF"}
X="0"
temp_prefix="/tmp/download-clean"
temp_inventory="${temp_prefix}-$$.inventory"
temp_tar="${temp_prefix}-$$.tar.bz2"
notemp_tar="$FOLDER/$DATE.tar.bz2"
temp_files="${temp_prefix}-$$.tempfiles"

growltxt() {
    echo "$@"
    hash growl 2>&- && growl -nosticky "$@"
}

get_path_exec() {
	if ! check_exec "$1"; then
		print_warning "$1 not found"
		exit;
	else
		echo $(which $1)
		return $S_EXT;
	fi
}

execute_supress_stout() {
	local commands="$@"
	[[ "$DEBUG" == 1 ]] && eval $commands && return $S_EXT
	[[ "$DEBUG" == 0 ]] && eval $commands 1> /dev/null && return $S_EXT
	return $U_RES
}

check_files() {
for file in $FROM
do
	[[ "$file" == "$ARCHIVE" ]] && continue
	((X++))
done
[[ "$DEBUG" == "ON" ]] && echo "X = $X"
[[ $X == 0 ]] && growltxt "No Files To Copy!" && exit
}

folder_prereq() {
for folder in $*
do
  [[ ! -e "$folder" ]] && mkdir -p "$folder"
done
}

inventoryprint() {
 DATESTAMP=$(date "+"%B" "%e", "%Y", "%r)
 printf "File Listing of Backup Directory as of $DATESTAMP\n\n"
 cat "$1"
}

move_files() {
for file in $FROM
do
	[[ "$file" == "$ARCHIVE_Save" ]] && continue
	[[ "$DEBUG" == "ON" ]] && echo $file
	mv "$file" "$FOLDER"
done

trap 'rm $temp_inventory; rm $temp_tar; mv $temp_files/* $FOLDER/ &> /dev/null; rm -R $temp_files; exit;' INT TERM
	
	#	Move files matching the "BZ2" to a temp folder
	#	these files do not need to be re-archived
	mkdir $temp_files
	for files in "$FOLDER/"*
	do
		[[ ${files##*.} == "bz2" ]] && mv $files $temp_files
	done
	
	#	Perform the tarring
	
	local tar_exec=$(get_path_exec "tar")
	
	local oldFOLDER="$(pwd)"; cd $FOLDER
	$tar_exec cjfv $temp_tar * &>1 | tee -a $temp_inventory
	cd "$oldFOLDER"; unset oldFolder
	
	#	rm all preexisting files existing in there
	for file in "$FOLDER/"*
	do
		[[ "$DEBUG" == "ON" ]] && echo "$file" && continue
		rm -R "$file"
	done

	#	Move pre-tared files into live
	for files in "$temp_files/"*
	do
		[[ ! -e $files ]] && continue
		mv "$files" "$FOLDER"
	done
	rm -R "$temp_files"
	
	inventoryprint $temp_inventory > $FOLDER/File_Listing.txt
	rm $temp_inventory
	mv $temp_tar $notemp_tar
trap - INT TERM
}

normalrun() {
    check_files
    #  File test sucessfull, at least one file exists...
    folder_prereq "$ARCHIVE" "$FOLDER"
    move_files
    growltxt 'Download Cleaning Finished!'
}

lock_ini() {
LOCK=`basename $0`; LOCK=${LOCK%.*}; LOCKDIR="/tmp/${LOCK}-lock"; PIDFILE="${LOCKDIR}/PID"; ENO_SUCCESS=0; ETXT[0]="SUCCESS"; ENO_GENERAL=1; ETXT[1]="GENERAL"; ENO_LOCKFAIL=2; ETXT[2]="LOCKFAIL"; ENO_RECVSIG=3; ETXT[3]="RECVSIG";
trap 'ECODE=$?; echo "[lockgen] Exit: ${ETXT[ECODE]}($ECODE)" >&2' 0
echo -n "[lockgen] Locking: "
if mkdir "${LOCKDIR}" &>/dev/null; then
	trap 'ECODE=$?;
	echo "[lockgen] Removing lock. Exit: ${ETXT[ECODE]}($ECODE)"
	rm -rf "${LOCKDIR}"' 0
	echo "$$" >"${PIDFILE}" 
	trap 'echo "[lockgen] Killed by a signal." >&2
	exit ${ENO_RECVSIG}' 1 2 3 15
	echo "success, installed signal handlers [$LOCKDIR]"
		#   LOCK SUCCESS PROCESS
else
	OTHERPID="$(cat "${PIDFILE}")"
	if [ $? != 0 ]; then
		echo "lock failed, PID ${OTHERPID} is active" >&2; exit ${ENO_LOCKFAIL}
	fi

	if ! kill -0 $OTHERPID &>/dev/null; then
		echo "removing stale lock of nonexistant PID ${OTHERPID}" >&2
		rm -rf "${LOCKDIR}"
		echo "[lockgen] restarting myself" >&2; exec "$0" "$@"
	else
		echo "lock failed, PID ${OTHERPID} is active" >&2
		exit ${ENO_LOCKFAIL}
	fi
fi
}

lock_ini
normalrun
