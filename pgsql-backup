#!/bin/bash
### Backup specified PostgreSQL Databases to file
# Original script:	MySQL Backup Script
#			VER. 2.5 - http://sourceforge.net/projects/automysqlbackup/
#			Copyright (c) 2002-2003 wipe_out@lycos.co.uk
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

# Version Number
VER=0.9.7

# Path to options file
user_rc="$1"
if [[ -n "$user_rc" -a -f "$user_rc" ]] ; then
	rc_fname="$user_rc"
elif [[ -f '~/.pgsql-backup.conf' ]] ; then
	rc_fname='~/.pgsql-backup.conf'
elif [[ -f '/etc/pgsql-backup.conf' ]] ; then
	rc_fname='/etc/pgsql-backup.conf'
elif [[ -f '/etc/pgsql-backup/options.conf' ]] ; then
	rc_fname='/etc/pgsql-backup/options.conf'
else
	echo 'Configuration file not found!'
	exit 1
fi

# Load the configuration file
if [[ -r "$rc_fname" ]] ; then
	source $rc_fname || { echo "Error while reading configuration file: $rc_fname"; exit 1; }
else
	echo "Unable to read configuration file: $rc_fname"
	exit 1
fi

# IO redirection for logging.
touch $log_stdout
exec 6>&1           # Link file descriptor #6 with stdout.
exec > $log_stdout     # stdout replaced with file $log_stdout.
touch $log_stderr
exec 7>&2           # Link file descriptor #7 with stderr.
exec 2> $log_stderr     # stderr replaced with file $log_stderr.

echo "Using configuration file '$rc_fname'"

# Validate the configuration
[[ -z "$MAILADDR" ]]	&& MAILADDR='root@localhost'
[[ -z "$DBHOST" ]]		&& DBHOST='localhost'
[[ -z "$DBNAMES" ]]		&& DBNAMES='all'
[[ -z "$MAILCONTENT" ]]	&& MAILCONTENT='stdout'
[[ -z "$MAXATTSIZE" ]]	&& MAXATTSIZE='4096'

# Make sure our binaries are good
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
[[ -z "$PG_DUMP" ]]	&& PG_DUMP=$(which pg_dump)
[[ -z "$PSQL" ]]	&& PSQL=$(which psql)
[[ -z "$RM" ]]		&& RM=$(which rm)
[[ -z "$MKDIR" ]]	&& MKDIR=$(which mkdir)
[[ -z "$DATE" ]]	&& DATE=$(which date)
[[ -z "$LN" ]]		&& LN=$(which ln)
[[ -z "$SED" ]]		&& SED=$(which sed)
[[ -z "$DU" ]]		&& DU=$(which du)
[[ -z "$GREP" ]]	&& GREP=$(which grep)
[[ -z "$CAT" ]]		&& CAT=$(which cat)
[[ -z "$MAILX" ]]	&& MAILX=$(which mailx)
[[ -z "$GZIP" ]]	&& GZIP=$(which gzip)
[[ -z "$BZIP2" ]]	&& BZIP2=$(which bzip2)
MISSING_BIN=''
[[ -x "$PG_DUMP" ]]	|| MISSING_BIN="$MISSING_BIN pgdump not found: $PG_DUMP\n"
[[ -x "$PSQL" ]]	|| MISSING_BIN="$MISSING_BIN psql not found: $PSQL\n"
[[ -x "$RM" ]]		|| MISSING_BIN="$MISSING_BIN rm not found: $RM\n"
[[ -x "$MKDIR" ]]	|| MISSING_BIN="$MISSING_BIN mkdir not found: $MKDIR\n"
[[ -x "$DATE" ]]	|| MISSING_BIN="$MISSING_BIN date not found: $DATE\n"
[[ -x "$LN" ]]		|| MISSING_BIN="$MISSING_BIN ln not found: $LN\n"
[[ -x "$SED" ]]		|| MISSING_BIN="$MISSING_BIN sed not found: $SED\n"
[[ -x "$DU" ]]		|| MISSING_BIN="$MISSING_BIN du not found: $DU\n"
[[ -x "$GREP" ]]	|| MISSING_BIN="$MISSING_BIN grep not found: $GREP\n"
[[ -x "$CAT" ]]		|| MISSING_BIN="$MISSING_BIN cat not found: $CAT\n"
[[ -x "$MAILX" ]]	|| MISSING_BIN="$MISSING_BIN mail not found: $MAILX\n"
[[ ! -x "$GZIP" -a "$COMP" = 'gzip' ]]		&& MISSING_BIN="$MISSING_BIN gzip not found: $GZIP\n"
[[ ! -x "$BZIP2" -a "$COMP" = 'bzip2' ]]	&& MISSING_BIN="$MISSING_BIN bzip2 not found: $BZIP2\n"
if [ -n "$MISSING_BIN" ] ; then
	echo "Some required programs were not found. Please check $rc_fname to ensure correct paths are set."
	echo "The missing files are:"
	echo -e $MISSING_BIN
fi

# Make all config from options.conf READ-ONLY
declare -r USERNAME
declare -r DBHOST
declare -r BACKUPDIR
declare -r MAILCONTENT
declare -r MAXATTSIZE
declare -r MAILADDR
declare -r DBEXCLUDE
declare -r CREATE_DATABASE
declare -r DOWEEKLY
declare -r COMP
declare -r LATEST
declare -r PG_DUMP
declare -r PSQL
declare -r GZIP
declare -r BZIP2
declare -r RM
declare -r MKDIR
declare -r DATE
declare -r LN
declare -r SED
declare -r DU
declare -r GREP
declare -r CAT
declare -r MAILX

FULLDATE=`$DATE +%Y-%m-%d_%Hh%Mm`	# Datestamp e.g 2002-09-21
DOW=`$DATE +%A`						# Day of the week e.g. Monday
DNOW=`$DATE +%u`					# Day number of the week 1 to 7 where 1 represents Monday
DOM=`$DATE +%d`						# Date of the Month e.g. 27
M=`$DATE +%B`						# Month e.g January
W=`$DATE +%V`						# Week Number e.g 37
log_stdout=$BACKUPDIR/$DBHOST-`$DATE +%N`.log		# Logfile Name
log_stderr=$BACKUPDIR/ERRORS_$DBHOST-`$DATE +%N`.log	# Logfile Name
BACKUPFILES=""
OPT="--blobs --format=${DUMPFORMAT}"			# OPT string for use with pg_dump

# Create required directories
[[ ! -e "$BACKUPDIR/daily" ]]	&& $MKDIR -p "$BACKUPDIR/daily"
[[ ! -e "$BACKUPDIR/weekly" ]]	&& $MKDIR -p "$BACKUPDIR/weekly"
[[ ! -e "$BACKUPDIR/monthly" ]]	&& $MKDIR -p "$BACKUPDIR/monthly"
if [[ "$LATEST" = "yes" ]] ; then
	[[ ! -e "$BACKUPDIR/latest" ]] && $MKDIR -p "$BACKUPDIR/latest"
	$RM -f $BACKUPDIR/latest/*
fi

# Output Extension (depends on the output format)
if [[ "$DUMPFORMAT" = 'tar' ]] ; then
	OUTEXT='tar'
elif [[ "$DUMPFORMAT" = 'plain' ]] ; then
	OUTEXT='sql'
else
	echo "Invalid output format configured. Defaulting to 'plain'"
	DUMPFORMAT='plain'
	OUTEXT='sql'
fi
OPT="$OPT --format=${DUMPFORMAT}"

#########################
# Functions

# Database dump function
dbdump () {
	local _args="$1"
	local _output_fname="$2"
	export PGPASSWORD="$DB_PASS"
	$PG_DUMP --username=$USERNAME --host=$DBHOST $OPT $_args > $_output_fname
	return $?
}

# Compression function plus latest copy
SUFFIX=""
compression () {
	local _fname="$1"

	if [[ "$COMP" = "gzip" ]] ; then
		echo Backup Information for "$_fname"
		$GZIP -f "$_fname"
		$GZIP -l "$_fname.gz"
		SUFFIX=".gz"
	elif [[ "$COMP" = "bzip2" ]] ; then
		echo Compression information for "$_fname.bz2"
		$BZIP2 -f -v $_fname 2>&1
		SUFFIX=".bz2"
	else
		echo "No compression option set, check advanced settings"
	fi
	if [[ "$LATEST" = "yes" ]] ; then
		$LN -f ${_fname}${SUFFIX} "$BACKUPDIR/latest/"
	fi	
	return 0
}

#########################################

# Run command before we begin
if [[ -n "$PREBACKUP" ]] ; then
	echo ======================================================================
	echo "Prebackup command output."
	echo
	eval $PREBACKUP
	echo
	echo ======================================================================
	echo
fi

if [[ "$SEPDIR" = "yes" ]] ; then # Check if CREATE DATABSE should be included in Dump
	if [[ "$CREATE_DATABASE" = "no" ]] ; then
		OPT="$OPT --no-create"
	else
		OPT="$OPT --create"
	fi
fi

# Hostname for LOG information
if [[ "$DBHOST" = "localhost" ]] ; then
	HOST=`hostname`
	if [[ "$SOCKET" ]] ; then
		OPT="$OPT --host=$SOCKET"
	fi
else
	HOST=$DBHOST
fi

# If backing up all DBs on the server
if [[ "$DBNAMES" = "all" ]] ; then
	export PGPASSWORD="$DB_PASS"
	DBNAMES=`$PSQL --username=$USERNAME --dbname=$CONNECT_DB -P format=Unaligned -tqc 'SELECT datname FROM pg_database;' | $SED 's/ /%/g'`

	# If DBs are excluded
	for exclude in $DBEXCLUDE ; do
		DBNAMES=`echo $DBNAMES | $SED "s/\b$exclude\b//g"`
	done

	MDBNAMES=$DBNAMES
fi

$CAT <<EOT
======================================================================
pgsql-backup VER $VER
   Based on AutoMySQLBackup
   http://sourceforge.net/projects/automysqlbackup/
======================================================================
Backup of PostgreSQL Database Server - $HOST
Started $($DATE)
======================================================================
EOT

# Monthly Full Backup of all Databases on the 1st of the month
if [[ $DOM = "01" ]] ; then
	for MDB in $MDBNAMES ; do
		MDB="`echo $MDB | $SED 's/%/ /g'`"

		echo Monthly Backup of $MDB...

		[[ ! -e "$BACKUPDIR/monthly/$MDB" ]] && $MKDIR -p "$BACKUPDIR/monthly/$MDB"
		dbdump "${MDB}" "${BACKUPDIR}/monthly/${MDB}/${MDB}_${FULLDATE}.${M}.${MDB}.${OUTEXT}"
		compression "${BACKUPDIR}/monthly/${MDB}/${MDB}_${FULLDATE}.${M}.${MDB}.${OUTEXT}"
		BACKUPFILES="${BACKUPFILES} ${BACKUPDIR}/monthly/${MDB}/${MDB}_${FULLDATE}.${M}.${MDB}.${OUTEXT}${SUFFIX}"
		echo '----------------------------------------------------------------------'
	done
fi

for DB in $DBNAMES ; do
	DB="`echo $DB | $SED 's/%/ /g'`"
	
	# Create Seperate directory for each DB
	[[ ! -e "$BACKUPDIR/daily/$DB" ]]	&& $MKDIR -p "$BACKUPDIR/daily/$DB"
	[[ ! -e "$BACKUPDIR/weekly/$DB" ]]	&& $MKDIR -p "$BACKUPDIR/weekly/$DB"
	
	if [[ $DNOW = $DOWEEKLY ]] ; then
		# Weekly Backup
		echo "Weekly Backup of Database '$DB'"
		echo "Rotating 5 weeks Backups..."
			if [ "$W" -le 05 ] ; then
				REMW=`expr 48 + $W`
			elif [ "$W" -lt 15 ];then
				REMW=0`expr $W - 5`
			else
				REMW=`expr $W - 5`
			fi
		$RM -f $BACKUPDIR/weekly/$DB/${DB}_week.$REMW.*
		echo
		dbdump "$DB" "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$FULLDATE.${OUTEXT}"
		compression "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$FULLDATE.${OUTEXT}"
		BACKUPFILES="$BACKUPFILES $BACKUPDIR/weekly/$DB/${DB}_week.$W.$FULLDATE.${OUTEXT}$SUFFIX"
		echo '----------------------------------------------------------------------'
	else
		# Daily Backup
		echo "Daily Backup of Database '$DB'"
		echo "Rotating last weeks Backup..."
		$RM -f $BACKUPDIR/daily/$DB/*.$DOW.*
		echo
		dbdump "$DB" "$BACKUPDIR/daily/$DB/${DB}_$FULLDATE.$DOW.${OUTEXT}"
		compression "$BACKUPDIR/daily/$DB/${DB}_$FULLDATE.$DOW.${OUTEXT}"
		BACKUPFILES="$BACKUPFILES $BACKUPDIR/daily/$DB/${DB}_$FULLDATE.$DOW.${OUTEXT}$SUFFIX"
		echo '----------------------------------------------------------------------'
	fi
done

$CAT <<EOT
Backup End `$DATE`
======================================================================
Total disk space used for backup storage..
Size - Location
$($DU -hs "$BACKUPDIR")
======================================================================
EOT

# Run command when we're done
if [[ -n "$POSTBACKUP" ]] ; then
	echo ======================================================================
	echo "Postbackup command output."
	echo
	eval $POSTBACKUP
	echo
	echo ======================================================================
fi

#Clean up IO redirection
exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
exec 1>&7 7>&-      # Restore stdout and close file descriptor #7.

case "$MAILCONTENT" in
'files')
	if [[ -s "$log_stderr" ]] ; then
		# Include error log if is larger than zero.
		BACKUPFILES="$BACKUPFILES $log_stderr"
		ERRORNOTE="WARNING: Error Reported - "
	fi
	# Get backup size
	ATTSIZE=$($DU -c $BACKUPFILES | $GREP "[[:digit:][:space:]]total$" | $SED s/\s*total//)
	if [[ $MAXATTSIZE -lt $ATTSIZE ]] ; then
		$CAT "$log_stdout" | $MAILX -s "WARNING! - PostgreSQL Backup exceeds set maximum attachment size on $HOST - $FULLDATE" $MAILADDR
	fi
;;
'log')
	$CAT "$log_stdout" | $MAILX -s "PostgreSQL Backup Log for $HOST - $FULLDATE" $MAILADDR
	if [[ -s "$log_stderr" ]] ; then
		$CAT "$log_stderr" | $MAILX -s "ERRORS REPORTED: PostgreSQL Backup error Log for $HOST - $FULLDATE" $MAILADDR
	fi
;;
'quiet')
	if [[ -s "$log_stderr" ]] ; then
		$MAILX -s "ERRORS REPORTED: PostgreSQL Backup error Log for $HOST - $FULLDATE" $MAILADDR <<EOT
=============================================
!!!!!! WARNING !!!!!!
Errors reported during AutoPostgreSQLBackup execution... BACKUP FAILED.
$($CAT $log_stderr)
=============================================
Full Log Below
=============================================
$($CAT $log_stdout)
=============================================
EOT
	fi
;;
*)
	if [[ -s "$log_stderr" ]] ; then
		$CAT <<EOT
=============================================
!!!!!! WARNING !!!!!!
Errors reported during AutoPostgreSQLBackup execution... BACKUP FAILED.
$($CAT $log_stderr)
=============================================
Full Log Below
=============================================
$($CAT $log_stdout)
=============================================
	else
		$CAT "$log_stdout"
	fi
;;
esac

# Clean up Logfile
eval $RM -f "$log_stdout"
eval $RM -f "$log_stderr"

exit [[ -s "$log_stderr" ]]
