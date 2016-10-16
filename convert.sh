#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# import support functions
source lib/functions.sh

########
# FAF converter script for changing unit LUA blueprint files into JSON
# Burke Lougheed
# Created 2016-10-08


########
# Validation and initialization
#
# ensure two paremeters are provided:
if [ "$#" -ne 2 ]; then
  # dun goofed; provide usage and example
  echo "ERROR: 2 parameters required"
  echo "USAGE: ./convert.sh [PATH TO /fa REPOSITORY] [LOCAL DESTINATION]"
  echo "EXAMPLE: ./convert.sh ~/workspace/repo/fa ~/workspace/dev/faf_unit_jsons"
  exit 1
else
  # initialize variables
  repo_dir=$1
  dest_dir=$2
  curr_dir=$PWD
  dest_jsons_dir=$dest_dir/unit_jsons
  temp_usage_dir=$dest_dir/temp
  units_repo_dir="$repo_dir/units"
fi
# check that the repo is already downloaded
if [ ! -d $repo_dir ]; then
  # repo does not exist
  echo "Repository directory does not exist!"
  exit 1
else
  # repo is there, pull and update:
  echo "Updating /fa repository ..."
  cd $repo_dir
  git pull
  cd $curr_dir
fi
# check that the destination directory exists
if [ ! -d $dest_dir ]; then
  printf "Destination folder does not exist, creating ... "
  mkdir $dest_dir
  echo "done"
else 
  # directory exists, truncate existing content
  printf "Destination folder exists, truncating ... "
  rm -rf $dest_dir/*
  echo "done"
fi


########
# Processing
# 
# get all the unit blueprint files
unit_list=`find $units_repo_dir -type f -name "*_unit.bp" -print | sort`
# get unit count
unit_count=`find $units_repo_dir -type f -name "*_unit.bp" -print | wc -l`
# initialize counter
i=1
# loop units, processing one by one...
for unit in $unit_list; do
  unit_id=`basename $unit`
  printf "Processing $unit_id - $i of $unit_count ... "
  # call the unit processor
  convertBlueprintToJSON $temp_usage_dir $dest_dir $unit
  echo "done"
  #increment counter
  ((i++))
done

# Completed at this point
echo "Completed successfully."
echo "JSONs located in: $dest_dir"