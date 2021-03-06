#!/bin/bash

#
#  Copyright (c) 2015, Facebook, Inc.
#  All rights reserved.
#
#  This source code is licensed under the BSD-style license found in the
#  LICENSE file in the root directory of this source tree. An additional grant
#  of patent rights can be found in the PATENTS file in the same directory.
#

# Created By Mike Dodge(http://fb.me/mikedodge04):
#
# Code_Sync
#   This function will download a ssh key from your defined web server as
#   $KEY_SERVER. It will use the downloaded ssh key to do an rsync from the
#   defined $RSYNC_SERVER to the local code/lib. It will overwrite any local
#   changes with what is on the $RSYNC_SERVER.
#
#   $KEY_SERVER:
#     This is a HTTPS server where you will store your ssh key for download
#   $KEY_PATH:
#     This is the rest of the web address used to download the key
#   $RSYNC_SERVER:
#     Server host name in which you are storing the /code/lib directory


#########################################################
###                   Global Vars                     ###
#########################################################
# If the Global var is empty && assign

# Server Paths
[[ -z "$KEY_SERVER" ]] && KEY_SERVER="http://WEB_SERVER.com/"
[[ -z "$KEY_PATH" ]] && KEY_PATH="DIR/rsync_key"
[[ -z "$RSYNC_SERVER" ]] && RSYNC_SERVER="CODE_SYNC_SERVER"

# Client Paths
[[ -z "$code" ]] && code="/Library/code"
[[ -z "$key" ]] && key="$code/key/rsync_key"
[[ -z "$lib" ]] && lib="$code/lib"
[[ -z "$modules" ]] && modules="$lib/modules"
[[ -z "$scripts" ]] && scripts="$lib/scripts"

#########################################################


function code_sync () {
  # Usage:  code_sync EXIT
  # Downloads latest changes to /Library/code/lib,
  # and deletes any files not on the server
  # EXIT should contain "exit" to exit on sync fail
  # if you pass exit as $1 it will quit on sync fail
  exit_on_failure="noexit"
  [[ "$1" = "exit" ]] && exit_on_failure="exit"
  download_key
  maintain_ssh_known_hosts
  rsync_lib "$exit_on_failure"
  code_sync_finsh
}



#########################################################
###               Supplement Functions                ###
#########################################################

  
function dl_logger () {
  # Usage:  dl_logger FAIL_MSG
  # Writes FAIL_MSG to syslog with the "code_sync" tag. Useful for Splunk
  # or other logging tools
  FAIL_MSG="$1"
  dl_logger_tag="code_sync"
  logger -t $dl_logger_tag "$FAIL_MSG"
}


function download_key () {
  # Usage:  download_key
  # Downloads the ssh key used to an rsync.
  mkdir -p $code/key &> /dev/null
  curl -s "$KEY_SERVER/$KEY_PATH" --O "$key" &>/dev/null
}


function code_sync_abort () {
  # Usage: abort MESSAGE EXIT
  # Echoes MESSAGE
  # EXIT must contain "exit" or "noexit", exit the script.
  echo "$1" >&2 || echo ""
  if [[ "$2" = "exit" ]] ; then
    . $modules/finish.sh; finish
    exit 1
  fi
  return 1
}

function maintain_ssh_known_hosts (){
  # Usage:  maintain_ssh_known_hosts
  # Ensures the /etc/ssh_known_hosts file is up to date with the version in codelib
  CODE_KNOWN_HOSTS="$lib/conf/ssh_known_hosts"
  KNOWN_HOSTS='/etc/ssh_known_hosts'
  . $modules/diff_replace.sh; diff_replace "$KNOWN_HOSTS" "$CODE_KNOWN_HOSTS"
}

function rsync_lib () {
  # Usage: rsync_lib EXIT
  # Input $1= exit, (optional). Exits on failure
  # Syncs the code library from your Rsync server down to the localhost

  exit_on_failure="noexit"
  [[ "$1" = "exit" ]] && exit_on_failure="exit"

  # Change permissions on the rsync key and pull down the code base with
  # an rsync using the key.  Delete any changes on the localhost that aren't 
  # on the server. Note, we are assuming that there is a 'util' account on 
  # your codesync server that has access to the code library on the server.
  chmod 700 $code/key/rsync_key
  rsync -av --delete -e "ssh -i $code/key/rsync_key" \
    util@"$RSYNC_SERVER":/code/lib $code/ &>/dev/null

   # Check for failure and log to syslog
  if [[ $? -ne 0 ]]; then
    dl_logger "Failed to rsync"
    msg="Code_Sync failed!"
    code_sync_abort "$msg" "$exit_on_failure"
  fi
}


function create_code_directories {
  # Create the dirs needed for code. This is where we like to keep all of the
  # necessary dirs for later.
  mkdir -p $code/key
  # Create the Logs dir
  mkdir -p $code/logs
  # Make sure the Log file exists
  touch $code/logs/log.txt
  # Create the tags dir
  mkdir -p $code/tags
  # Create the var dir
  mkdir -p $code/var
  # expecting errors, so im returning 0
  return 0
}


function set_code_permissions {
  # Set lib only to root access
  chown -R root:root $lib &>/dev/null
  # Allow bin to be used by admin
  #Set the correct permissions for the code dir
  chmod -R 755 $lib &> /dev/null
  # excpeting errors, so im returning 0
  return 0
}


function code_sync_finsh () {
  # Creates code dirs, and Sets Premissions.
  create_code_directories
  set_code_permissions
}
