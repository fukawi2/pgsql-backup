<!---
Test changes using: http://daringfireball.net/projects/markdown/dingus
-->

# pgsql-backup

A script for automated backups of PostgreSQL Databases

This script is a fork of "*MySQL Backup Script*" version 2.5 Copyright &copy;
2002-2003 <wipe_out@lycos.co.uk> available from:

[http://sourceforge.net/projects/automysqlbackup/](http://sourceforge.net/projects/automysqlbackup/)

## Overview

This script is designed to be run daily, but can be run more often. Rolling
daily, weekly and monthly backups are created in the specified location for
each database requested to be backed up. Backups can be optionally compressed
to save diskspace. Backups can also be optionally emailed as attachments.

## Installation and Usage

A Makefile is included; running `make install` will install to /usr/local

    make install

Use `PREFIX` to change install location

    make PREFIX=/opt install

You will probably want the script to run on a regular basis; you can do this
using cron. Create `/etc/cron.d/pgsql-backup` with the following contents:

    0 1 * * * root /usr/local/bin/pgsql-backup

This will run the script at 1.00am every day. Refer to the cron man page for
more information about scheduling with cron.

### Configuration

Refer to the man page for full details of all available configuration options.
At a minimum, you will most likely need to ensure the following options are
valid for your environment:

* `CONFIG_BACKUPDIR`

* `CONFIG_PGUSER`

* `CONFIG_PGPASSWORD`

* `CONFIG_PGHOST`

* `CONFIG_PGPORT`

* `CONFIG_PGDATABASE`

### PostgreSQL Configuration

Refer to the man page for details about configuring PostgreSQL permissions in
an appropriate manner for pgsql-backup.
