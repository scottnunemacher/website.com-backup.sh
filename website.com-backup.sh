#!/usr/bin/env bash
set -o pipefail

# -----------------------------
# About website.com-backup.sh
# -----------------------------
# A simple script to backup a PHP/MySQL based website like Wordpress, even
# on shared-hosting without root privileges.
# 
# Run with an optional comment (single-word-or-phrase-but-no-spaces):
#   `./website.com-backup.sh SAVE-ME`
# will produce (showing example location):
#   /home/user/backups/website.com/website.com-20211101-040523Z-SAVE-ME/
#     ├─ website.com-20211101-040523Z-SAVE-ME-db.sql.gz
#     └─ website.com-20211101-040523Z-SAVE-ME-files.tar.gz
#
# Can be scheduled to run via crontab:
# `0 0 * * * /absolute/path/to/website.com-backup.sh`

# === Begin Variable edits ====
# Set these variables then read every comment before running.
# Name of website
SITE="website.com"
# ABSOLUTE Location of backup dir (leave off trailing forward slash)
BACKUPROOT="/home/user/backups"
# ABSOLUTE Location of webroot dir (leave off trailing forward slash)
WEBROOT="/home/user/public_html"
# === End Variable edits ======

# -----------------------------
# Database Details
# -----------------------------
# Database credentials from Wordpress wp-config file, otherwise modify to suit.
DBNAME=`cat $WEBROOT/wp-config.php | grep DB_NAME | cut -d \' -f 4`
DBUSER=`cat $WEBROOT/wp-config.php | grep DB_USER | cut -d \' -f 4`
DBPASS=`cat $WEBROOT/wp-config.php | grep DB_PASSWORD | cut -d \' -f 4`

# -----------------------------
# Optional User Comment
# -----------------------------
# Create optional comment.
if [ "${1}" ]
then
  COMMENT="-${1}"
fi

# -----------------------------
# Backup Details
# -----------------------------
# Set backup files name:
BACKUPNAME=$SITE-$(date -u +"%Y%m%d-%H%M%SZ")-`whoami`$COMMENT
# Set backup directory.
BACKUPDIR="$BACKUPROOT/$SITE/$BACKUPNAME"

# -----------------------------
# Functions
# -----------------------------
# Check for error each step.
# Print text to display on result.
check_errors() {
  # Parameter $1 is the return code tested.
  # Parameter $2 is text to display on success.
  # Parameter $3 is text to display on failure.
  if [[ $1 -eq 0 ]]; then
      printf "\xE2\x9C\x85 $2\n"
  else
      printf "\xE2\x9D\x8C ERROR: $1 - $3\n"
      exit $1
  fi
}

# Trap's cleanup function.
cleanup() {
  printf "\xE2\x9C\x85 Cleanup: Deleting temporary credentials file.\n"
  sleep 2
  rm -f "$TMPFILE"
  printf "\xE2\x9C\x85 Cleanup: Temporary credentials file deleted.\n"
  sleep 2
  printf "\xE2\x9C\x85 Cleanup: Runnning unset.\n"
  sleep 2
  unset SITE BACKUPROOT WEBROOT DBNAME DBUSER DBPASS COMMENT BACKUPNAME BACKUPDIR TMPFILE
  printf "\xE2\x9C\x85 Cleanup: Complete.\n"
  sleep 2
  exit
}

# ------------------------------
# Script
# ------------------------------
# Step 0: Notify if login shell
echo $(shopt | grep login_shell)

# Step 1: Create backup dir
mkdir -p $BACKUPDIR -m 0755
check_errors $? "Step 1:  Backup directory created." "Could not create backup directory. Check Step 1."

# Step 2: Create temporary credentials file (deleted by trap)
TMPFILE=$(mktemp -p $BACKUPDIR -t "temp-mysql-credentials.XXXXXXXX")
echo "[mysqldump]" > $TMPFILE
echo "user=$DBUSER" >> $TMPFILE
echo "password=$DBPASS" >> $TMPFILE
check_errors $? "Step 2:  Temporary credentials file created." "Could not create temporary credentials file. Check Step 2."

# Step 3: Create the backup of database in backup dir:
mysqldump --defaults-file=$TMPFILE --no-tablespaces $DBNAME | gzip > $BACKUPDIR/$BACKUPNAME-db.sql.gz
check_errors $? "Step 3:  Database backup created." "Could not create database backup. Check Step 3."

# Step 4: Create the backup of files in backup dir:
tar -czf $BACKUPDIR/$BACKUPNAME-files.tar.gz $WEBROOT
check_errors $? "Step 4:  Files backup created." "Could not create files backup. Check Step 4."

# Run trap cleanup function on SIGHUP(1), SIGINT(2), SIGQUIT(3), SIGABRT(6), SIGTERM(15), ERR & EXIT.
trap cleanup SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM ERR EXIT

# Done.
