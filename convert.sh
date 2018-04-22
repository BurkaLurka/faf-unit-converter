#!/bin/bash
#set -o errexit
#set -o pipefail
#set -o nounset

# import support functions
source lib/functions.sh

########
# FAF converter script for changing unit LUA blueprint files into JSON
# Burke Lougheed
# Created 2016-10-08
# Last update - 2018-04-21

########
# Validation and initialization
#
# ensure two paremeters are provided:
# initialize variables with defaults
curr_dir=$PWD
repo_dir=$PWD/../fa
dest_dir=$PWD/units
temp_dir=$dest_dir/temp
units_repo_dir="$repo_dir/units"
verbose_logging="false"
single_unit=""
failed_units=()
# process arguments, overrides defaults as flagged
process_args $@

# check that the repo is already there
if [ ! -d $repo_dir ]; then
  # repo does not exist
  error_log "Repository directory \"$repo_dir\" does not exist!"
  exit $error_repository_folder_not_found
fi
# check that the destination directory exists
if [ ! -d $dest_dir ]; then
  # attempt to create directory, exit if it fails
  mkdir $dest_dir
  if [ "$?" -ne "0" ]; then
    error_log "Failed to create destination folder \"$dest_dir\""
    exit $error_failed_to_create_destination_folder
  else
    info_log "Created destination folder \"$dest_dir\""
  fi
else
  # directory exists, truncate existing content
  warn_log "Destination folder exists already! Contents will be removed."
  rm -rf $dest_dir/*
  if [ "$?" -ne "0" ]; then
    error_log "Failed to clear out destination folder \"$dest_dir\""
    exit $error_failed_to_clear_out_destination_folder
  else
    info_log "Cleared out contents of \"$dest_dir\""
  fi
fi

########
# Processing
#
# get all the unit blueprint files
unit_list=`find $units_repo_dir -type f -name "*_unit.bp" -print | sort`
# get unit count
unit_count=`find $units_repo_dir -type f -name "*_unit.bp" -print | wc -l | perl -pe 's/\s*//g'`

# Did single unit get set, and does that unit exist?
if [ "$single_unit" != "" ]; then
  info_log "Extracting single unit $single_unit only"
  if [ `echo "$unit_list" | grep ${single_unit}_unit.bp | wc -l` -ne 1 ]; then
    # unit not in the list
    error_log "Unit $single_unit does not exist"
    exit $error_unit_does_not_exist
  else
    # unit exists, extract it and exit
    unit_path=`echo "$unit_list" | grep ${single_unit}_unit.bp`
    bp_to_json $temp_dir $dest_dir $unit_path
    check_error_and_log "${single_unit}_unit.bp"
  fi
else
  # single unit not flagged, run all units
  info_log "Extracting all units"
  # initialize counter
  counter=1
  # loop units, processing one by one...
  for unit in $unit_list; do
    unit_id=`basename $unit`
    info_log "Processing $unit_id - $counter of $unit_count ... "
    # call the unit processor
    bp_to_json $temp_dir $dest_dir $unit
    check_error_and_log $unit_id
    #increment counter
    ((counter++))
    #break
  done
fi

# Completed at this point
final_report
