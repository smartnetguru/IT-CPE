#!/bin/bash

#
#  Copyright (c) 2015, Facebook, Inc.
#  All rights reserved.
#
#  This source code is licensed under the BSD-style license found in the
#  LICENSE file in the root directory of this source tree. An additional grant
#  of patent rights can be found in the PATENTS file in the same directory.
#

function wait_for_internet () {
  # wait_for_internet loop
  # This script will loop until the computer is on the internet.
  # Then it will run the script or function passed.

  Version="2.0"
  logger -t code-wait_for_internet "$@"

  # Loop until the machine is on the network
  check_internet
  while [[ "$check_internet" != "True" ]]; do
    sleep 300
    check_internet
  done

  # Test if nothing is being passed
  if [ -z "$@" ] ; then
    return
  fi

  # Test if func is passed and run
  TEST=`type $@ | grep "is a function"`
  if [ -n "$TEST" ] ; then
    $@
    return
  fi

  # run script with params
  sh $@
}
