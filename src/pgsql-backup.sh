#!/usr/bin/env bash
### Backup specified PostgreSQL Databases to file
# Original script:  MySQL Backup Script
#      VER. 2.5 - http://sourceforge.net/projects/automysqlbackup/
#      Copyright (c) 2002-2003 wipe_out@lycos.co.uk
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
VER=0.9.10

set -e  # treat any error as fatal

### EXIT CODES
# 0 = OK
# 1 = Unspecified Error
# 2 = Configuration File Error
# 3 = Permission Denied

# Path to options file
user_rc="$1"
if [[ -n "$user_rc" && -f "$user_rc" ]] ; then
  rc_fname="$user_rc"
elif [[ -f '~/.pgsql-backup.conf' ]] ; then
  rc_fname='~/.pgsql-backup.conf'
elif [[ -f '/etc/pgsql-backup.conf' ]] ; then
  rc_fname='/etc/pgsql-backup.conf'
elif [[ -f '/etc/pgsql-backup/options.conf' ]] ; then
  rc_fname='/etc/pgsql-backup/options.conf'
else
  echo 'Configuration file not found!' >&2
  exit 2
fi

# Load the configuration file
[[ ! -r "$rc_fname" ]] && { echo "Unable to read configuration file: $rc_fname; Permission Denied" >&2; exit 3; }
source $rc_fname || { echo "Error reading configuration file: $rc_fname" >&2; exit 2; }

# Validate the configuration
MAILADDR=${MAILADDR-root@localhost}   # where to send reports to
DBHOST=${DBHOST-localhost}            # database server to connect to
DBNAMES=${DBNAMES-all}                # database names to backup
MAILCONTENT=${MAILCONTENT-stdout}     # where to display output
MAXATTSIZE=${MAXATTSIZE-4096}         # maximum email attachment size

# Make sure our binaries are good
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
[[ -z "${PG_DUMP}" ]] && PG_DUMP=$(which pg_dump 2> /dev/null)
[[ -z "${PSQL}" ]]    && PSQL=$(which psql 2> /dev/null)
[[ -z "${MAILX}" ]]   && MAILX=$(which mail 2> /dev/null)
[[ -z "${GZIP}" ]]    && GZIP=$(which gzip 2> /dev/null)
[[ -z "${BZIP2}" ]]   && BZIP2=$(which bzip2 2> /dev/null)
MISSING_BIN=''
[[ -x "$PG_DUMP" ]] || MISSING_BIN="$MISSING_BIN \t'pgdump' not found: $PG_DUMP\n"
[[ -x "$PSQL" ]]    || MISSING_BIN="$MISSING_BIN \t'psql' not found: $PSQL\n"
[[ -x "$MAILX" ]]   || MISSING_BIN="$MISSING_BIN \t'mail' not found: $MAILX\n"
[[ ! -x "$GZIP" && "$COMP" = 'gzip' ]]    && MISSING_BIN="$MISSING_BIN 'gzip' not found: $GZIP\n"
[[ ! -x "$BZIP2" && "$COMP" = 'bzip2' ]]  && MISSING_BIN="$MISSING_BIN 'bzip2' not found: $BZIP2\n"
[[ ! -x "$XZ" && "$COMP" = 'xz' ]]        && MISSING_BIN="$MISSING_BIN 'xz' not found: $xz2\n"
if [[ -n "$MISSING_BIN" ]] ; then
  echo "Some required programs were not found. Please check $rc_fname to ensure correct paths are set." >&2
  echo "The missing files are:" >&2
  echo -e $MISSING_BIN >&2
fi

# strip any trailing slash from BACKUPDIR
echo ${BACKUPDIR%/}

# Make all config from options.conf READ-ONLY
declare -r PGUSER
declare -r PGPASSWORD
declare -r PGHOST
declare -r PGPORT
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
declare -r MAILX

# export PG environment variables for libpq
export PGUSER PGPASSWORD PGHOST PGPORT PGDATABASE

FULLDATE=$(date +%Y-%m-%d_%Hh%Mm)  # Datestamp e.g 2002-09-21_11h52m
DOW=$(date +%A)                    # Day of the week e.g. "Monday"
DNOW=$(date +%u)                   # Day number of the week 1 to 7 where 1 represents Monday
DOM=$(date +%d)                    # Date of the Month e.g. 27
M=$(date +%B)                      # Month e.g "January"
W=$(date +%V)                      # Week Number e.g 37
backupfiles=""
OPT="--blobs --format=${DUMPFORMAT}"  # OPT string for use with pg_dump

# Does backup dir exist and can we write to it?
[[ ! -d "$BACKUPDIR" ]]  && { echo "Destination $BACKUPDIR does not exist or is inaccessible; Aborting" >&2; exit 1; }
[[ ! -w "$BACKUPDIR" ]]  && { echo "Unable to write to $BACKUPDIR; Aborting" >&2; exit 3; }

# Create required directories
[[ ! -e "$BACKUPDIR/daily" ]]   && mkdir -p "$BACKUPDIR/daily"
[[ ! -e "$BACKUPDIR/weekly" ]]  && mkdir -p "$BACKUPDIR/weekly"
[[ ! -e "$BACKUPDIR/monthly" ]] && mkdir -p "$BACKUPDIR/monthly"
if [[ "$LATEST" = "yes" ]] ; then
  [[ ! -e "$BACKUPDIR/latest" ]] && mkdir -p "$BACKUPDIR/latest"
  # cleanup previous 'latest' links
  rm -f $BACKUPDIR/latest/*
fi

# Output Extension (depends on the output format)
if [[ "$DUMPFORMAT" = 'tar' ]] ; then
  OUTEXT='tar'
elif [[ "$DUMPFORMAT" = 'plain' ]] ; then
  OUTEXT='sql'
elif [[ "$DUMPFORMAT" = 'custom' ]] ; then
  OUTEXT='c'
else
  echo "Invalid output format configured. Defaulting to 'custom'" >&2
  DUMPFORMAT='custom'
  OUTEXT='c'
fi
OPT="$OPT --format=${DUMPFORMAT}"

# IO redirection for logging.
log_stdout=$(mktemp "$BACKUPDIR/$DBHOST-$$-log.XXXX") # Logfile Name
log_stderr=$(mktemp "$BACKUPDIR/$DBHOST-$$-err.XXXX") # Error Logfile Name
touch $log_stdout
exec 6>&1           # Link file descriptor #6 with stdout.
exec > $log_stdout  # stdout replaced with file $log_stdout.
touch $log_stderr
exec 7>&2           # Link file descriptor #7 with stderr.
exec 2> $log_stderr # stderr replaced with file $log_stderr.

#########################
# Functions

# Database dump function
dbdump () {
  local _args="$1"
  local _output_fname="$2"
  $PG_DUMP $OPT $_args > $_output_fname
  return $?
}

# Compression function plus latest copy
SUFFIX=""
compression () {
  local _fname="$1"

  if [[ "$COMP" = "gzip" ]] ; then
    SUFFIX=".gz"
    echo Backup Information for "${_fname}${SUFFIX}"
    $GZIP -f "$_fname"
    $GZIP -l "${_fname}${SUFFIX}"
  elif [[ "$COMP" = "bzip2" ]] ; then
    SUFFIX=".bz2"
    echo Compression information for "${_fname}${SUFFIX}"
    $BZIP2 -f -v $_fname 2>&1
  elif [[ "$COMP" = "xz" ]] ; then
    SUFFIX=".xz"
    echo Compression information for "${_fname}${SUFFIX}"
    $XZ --compress --force $_fname 2>&1
    $XZ--list ${_fname}${SUFFIX} 2>&1
  elif [[ "$COMP" = "none" ]] && [[ "$DUMPFORMAT" = "custom" ]] ; then
    # the 'custom' dump format compresses by default inside pg_dump if postgres
    # was built with zlib at compile time.
    echo "Using in-built compression of 'custom' format (if available)"
  elif [[ "$COMP" = "none" ]] ; then
    echo "Using no compression"
  else
    echo "No valid compression option set, check advanced settings"
  fi
  if [[ "$LATEST" = "yes" ]] ; then
    ln -f ${_fname}${SUFFIX} "$BACKUPDIR/latest/"
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

# ask pg_dump to include CREATE DATABASE in the dump output?
if [[ "$CREATE_DATABASE" = "no" ]] ; then
  OPT="$OPT --no-create"
else
  OPT="$OPT --create"
fi

# Hostname for LOG information; also append socket to
if [[ "$DBHOST" = "localhost" ]] ; then
  HOST="$hostname"
  [[ "$SOCKET" ]] && OPT="$OPT --host=$SOCKET"
else
  HOST=$DBHOST
fi

# If backing up all DBs on the server
if [[ "$DBNAMES" = "all" ]] ; then
  DBNAMES=$($PSQL -P format=Unaligned -tqc 'SELECT datname FROM pg_database;' | sed 's/ /%/g')

  # If DBs are excluded
  for exclude in $DBEXCLUDE ; do
    DBNAMES=$(echo $DBNAMES | sed "s/\b$exclude\b//g")
  done
fi

cat <<EOT
======================================================================
pgsql-backup VER $VER
   Based on AutoMySQLBackup
   http://sourceforge.net/projects/automysqlbackup/
======================================================================
Backup of PostgreSQL Database Server - $HOST
Started $(date)
======================================================================
EOT

for DB in $DBNAMES ; do
  DB=$(echo $DB | sed 's/%/ /g')

  # Create Seperate directory for each DB
  [[ ! -e "$BACKUPDIR/monthly/$MDB" ]]  && mkdir -p "$BACKUPDIR/monthly/$MDB"
  [[ ! -e "$BACKUPDIR/weekly/$DB" ]]    && mkdir -p "$BACKUPDIR/weekly/$DB"
  [[ ! -e "$BACKUPDIR/daily/$DB" ]]     && mkdir -p "$BACKUPDIR/daily/$DB"

  if [[ $DOM = "01" ]] ; then
    # Monthly Backup
    echo Monthly Backup of $MDB...
    # note we never automatically delete old monthly backups
    dbdump "${MDB}" "${BACKUPDIR}/monthly/${MDB}/${MDB}_${FULLDATE}.${M}.${MDB}.${OUTEXT}"
    compression "${BACKUPDIR}/monthly/${MDB}/${MDB}_${FULLDATE}.${M}.${MDB}.${OUTEXT}"
    backupfiles="${backupfiles} ${BACKUPDIR}/monthly/${MDB}/${MDB}_${FULLDATE}.${M}.${MDB}.${OUTEXT}${SUFFIX}"
    echo '----------------------------------------------------------------------'
  elif [[ $DNOW = $DOWEEKLY ]] ; then
    # Weekly Backup
    echo "Weekly Backup of Database '$DB'"
    echo "Rotating 5 weeks Backups..."
    if [ $W -le 05 ] ; then
      REMW="$(expr 48 + $W)"
    elif [ $W -lt 15 ];then
      REMW="0$(expr $W - 5)"
    else
      REMW="$(expr $W - 5)"
    fi
    rm -f $BACKUPDIR/weekly/$DB/${DB}_week.$REMW.*
    echo
    dbdump "$DB" "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$FULLDATE.${OUTEXT}"
    compression "$BACKUPDIR/weekly/$DB/${DB}_week.$W.$FULLDATE.${OUTEXT}"
    backupfiles="$backupfiles $BACKUPDIR/weekly/$DB/${DB}_week.$W.$FULLDATE.${OUTEXT}$SUFFIX"
    echo '----------------------------------------------------------------------'
  else
    # Daily Backup
    echo "Daily Backup of Database '$DB'"
    echo "Rotating last weeks Backup..."
    rm -f $BACKUPDIR/daily/$DB/*.$DOW.*
    echo
    dbdump "$DB" "$BACKUPDIR/daily/$DB/${DB}_$FULLDATE.$DOW.${OUTEXT}"
    compression "$BACKUPDIR/daily/$DB/${DB}_$FULLDATE.$DOW.${OUTEXT}"
    backupfiles="$backupfiles $BACKUPDIR/daily/$DB/${DB}_$FULLDATE.$DOW.${OUTEXT}$SUFFIX"
    echo '----------------------------------------------------------------------'
  fi
done

cat <<EOT
Backup End $(date)
======================================================================
Total disk space used for backup storage..
Size - Location
$(du -hs "$BACKUPDIR")
======================================================================
EOT

# Run command when we're done
if [[ -n "$POSTBACKUP" ]] ; then
  echo ======================================================================
  echo "Postbackup command output."
  echo
  new_backupfiles=$($POSTBACKUP $backupfiles)
  [[ -n "$new_backupfiles" ]] && backupfiles=$new_backupfiles
  echo
  echo ======================================================================
fi

# Clean up IO redirection
exec 1>&6 6>&-      # Restore stdout and close file descriptor #6.
exec 1>&7 7>&-      # Restore stdout and close file descriptor #7.

case "$MAILCONTENT" in
'files')
  if [[ -s "$log_stderr" ]] ; then
    # Include error log if is larger than zero.
    backupfiles="$backupfiles $log_stderr"
    ERRORNOTE="WARNING: Error Reported - "
  fi
  # Get backup size
  ATTSIZE=$(du -c $backupfiles | grep "[[:digit:][:space:]]total$" | sed s/\s*total//)
  if [[ $MAXATTSIZE -lt $ATTSIZE ]] ; then
    cat "$log_stdout" | $MAILX -s "WARNING! - PostgreSQL Backup exceeds set maximum attachment size on $HOST - $FULLDATE" $MAILADDR
  fi
;;
'log')
  cat "$log_stdout" | $MAILX -s "PostgreSQL Backup Log for $HOST - $FULLDATE" $MAILADDR
  if [[ -s "$log_stderr" ]] ; then
    cat "$log_stderr" | $MAILX -s "ERRORS REPORTED: PostgreSQL Backup error Log for $HOST - $FULLDATE" $MAILADDR
  fi
;;
'quiet')
  if [[ -s "$log_stderr" ]] ; then
    $MAILX -s "ERRORS REPORTED: PostgreSQL Backup error Log for $HOST - $FULLDATE" $MAILADDR <<EOT
=============================================
!!!!!! WARNING !!!!!!
Errors reported during AutoPostgreSQLBackup execution... BACKUP FAILED.
$(cat $log_stderr)
=============================================
Full Log Below
=============================================
$(cat $log_stdout)
=============================================
EOT
  fi
;;
*)
  if [[ -s "$log_stderr" ]] ; then
    cat <<EOT
=============================================
!!!!!! WARNING !!!!!!
Errors reported during AutoPostgreSQLBackup execution... BACKUP FAILED.
$(cat $log_stderr)
=============================================
Full Log Below
=============================================
$(cat $log_stdout)
=============================================
EOT
  else
    cat "$log_stdout"
  fi
;;
esac

if [[ -s "$log_stderr" ]]; then
    STATUS=1
else
    STATUS=0
fi

# Clean up Logfile
rm -f "$log_stdout"
rm -f "$log_stderr"

exit $STATUS
