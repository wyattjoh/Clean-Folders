#!/bin/bash
DATE="$(date +%Y%m%d)"
#DATE="20110721"
ARCHIVE="/Users/wyattjohnson/Downloads/Archives"
FOLDER="$ARCHIVE/$DATE"
FROM="/Users/wyattjohnson/Downloads/*"
DEBUG=${1-"OFF"}
X="0"
temp_inventory="/tmp/download-clean-$$.inventory"
temp_tar="/tmp/download-clean-$$.tar.bz2"
notemp_tar="$FOLDER/$DATE.tar.bz2"
temp_files="/tmp/download-clean-$$.tempfiles"

growltxt() {
    echo "$@"
    hash growl 2>&- && growl -nosticky "$@"
}

check_files() {
for file in $FROM
do
	[[ "$file" == "/Users/wyattjohnson/Downloads/Archives" ]] && continue
	((X++))
done
[[ "$DEBUG" == "ON" ]] && echo "X = $X"
}

folder_prereq() {
for folder in $*
do
  [[ ! -e "$folder" ]] && mkdir "$folder"
done
}

inventory() {
 DATESTAMP=$(date "+"%B" "%e", "%Y", "%r)
 OLDIFS=$IFS
 IFS=$'\n'
 printf "File Listing of Backup Directory as of $DATESTAMP\n\n"
 for files in $(find $* -maxdepth 0); do
	[[ -d "${files}" ]] && continue
	echo -e "${files}"
 done
 IFS=$OLDIFS
}

move_files() {
for file in $FROM
do
	[[ "$file" == "/Users/wyattjohnson/Downloads/Archives" ]] && continue
	[[ "$DEBUG" == "ON" ]] && echo $file
	mv "$file" "$FOLDER"
done

trap 'rm $temp_inventory; rm $temp_tar; mv $temp_files/* $FOLDER/ &> /dev/null; rm -R $temp_files; exit;' INT TERM
	inventory "$FOLDER/"* > $temp_inventory
	
	#	Move files matching the "BZ2" to a temp folder
	#	these files do not need to be re-archived
	mkdir $temp_files
	for files in "$FOLDER/"*
	do
		[[ ${files##*.} == "bz2" ]] && mv $files $temp_files
	done
	
	#	Perform the tarring
	tar cjf $temp_tar $FOLDER &> /dev/null
	
	#	Kill all preexisting files existing in there
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
	
	cat $temp_inventory > $FOLDER/File_Listing.txt
	rm $temp_inventory
	mv $temp_tar $notemp_tar
trap - INT TERM
}

archive_old() {

append_tar() {
TARFOLDER=$1
TAR="$TARFOLDER/$(basename $TARFOLDER).tar"
#printf $TAR"\n\n"
for files in $1/*
do
  [[ "$TAR" == "$files"  ]] && continue
  #echo $files
  tar --update --file="$TAR" "$files"
  
  #printf "$files --> $TAR\n"

  rm -R $files
done
}


OLDESTDATE=$(($DATE-5))
for folders in $ARCHIVE/*
do
  [[ "$folders" == "$ARCHIVE/*" ]] && continue
  [[ "$(basename $folders)" -gt "$OLDESTDATE" ]] && continue
  [[ -e "$folders/$(basename $folders).tar" ]] && append_tar "$folders" && continue
  tar -czhf "$folders/$(basename $folders).tar" "$folders"/*
  for files in $folders/*
  do
    [[ "$files" == "$folders/$(basename $folders).tar" ]] && continue
    #rm -R $files
    echo $files
  done

  #echo "$folders/$(basename $folders).tar"
done
}

normalrun() {
    check_files
    [[ $X == 0 ]] && growltxt "No Files To Copy!" && exit
    #  File test sucessfull, at least one file exists...
    folder_prereq "$ARCHIVE" "$FOLDER"
    move_files
    growltxt 'Download Cleaning Finished!'
}

lock_ini() {
##################################################
### Locking and Initialization  ##################
##################################################

# lock dirs/files
LOCK=`basename $0`
LOCK=${LOCK%.*}
LOCKDIR="/tmp/${LOCK}-lock"
PIDFILE="${LOCKDIR}/PID"

# exit codes and text for them - additional features nobody needs :-)
ENO_SUCCESS=0; ETXT[0]="SUCCESS"
ENO_GENERAL=1; ETXT[1]="GENERAL"
ENO_LOCKFAIL=2; ETXT[2]="LOCKFAIL"
ENO_RECVSIG=3; ETXT[3]="RECVSIG"

###
### start locking attempt
###

trap 'ECODE=$?; echo "[lockgen] Exit: ${ETXT[ECODE]}($ECODE)" >&2' 0
echo -n "[lockgen] Locking: "

if mkdir "${LOCKDIR}" &>/dev/null; then

# lock succeeded, install signal handlers before storing the PID just in case 
# storing the PID fails
trap 'ECODE=$?;
echo "[lockgen] Removing lock. Exit: ${ETXT[ECODE]}($ECODE)"
rm -rf "${LOCKDIR}"' 0
echo "$$" >"${PIDFILE}" 
# the following handler will exit the script on receiving these signals
# the trap on "0" (EXIT) from above will be triggered by this trap's "exit" command!
trap 'echo "[lockgen] Killed by a signal." >&2
exit ${ENO_RECVSIG}' 1 2 3 15
echo "success, installed signal handlers [$LOCKDIR]"

# sucessfull locking completed

#   Execute based on options


else

# lock failed, now check if the other PID is alive
OTHERPID="$(cat "${PIDFILE}")"

# if cat wasn't able to read the file anymore, another instance probably is
# about to remove the lock -- exit, we're *still* locked
if [ $? != 0 ]; then
echo "lock failed, PID ${OTHERPID} is active" >&2
exit ${ENO_LOCKFAIL}
fi

if ! kill -0 $OTHERPID &>/dev/null; then
# lock is stale, remove it and restart
echo "removing stale lock of nonexistant PID ${OTHERPID}" >&2
rm -rf "${LOCKDIR}"
echo "[lockgen] restarting myself" >&2
exec "$0" "$@"
else
# lock is valid and OTHERPID is active - exit, we're locked!
echo "lock failed, PID ${OTHERPID} is active" >&2
exit ${ENO_LOCKFAIL}
fi

fi
}

lock_ini
normalrun
