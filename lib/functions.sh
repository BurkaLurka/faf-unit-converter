#!/bin/bash

##################
# Library functions for use in the converter.sh script
##################
#
#########
# Colour variables for logging
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

# Error codes
error_unexpected_parameter=1
error_bad_parameter=2
error_repository_folder_not_found=3
error_failed_to_create_destination_folder=4
error_failed_to_clear_out_destination_folder=5
error_unit_does_not_exist=6
error_failed_to_execute_regex=7
error_failed_to_validate_json=8

# logging functions
#
function info_log() {
  [ $verbose_logging = "true" ] && echo -e "  [INFO] : $1"
  return 0
}
function error_log() {
  echo -e "\n [${RED}ERROR${NC}] : $1\n"
  return 0
}
function warn_log() {
  [ $verbose_logging = "true" ] && echo -e "  [${YELLOW}WARN${NC}] : $1"
  return 0
}

function run_regex() {
  local regex_pattern="$1"
  perl -pe "$regex_pattern" -i.orig$i $usage_unit && ((i++))
  if [ "$?" -ne "0" ]; then
    error_log "Failed to execute regex -- $regex_pattern"
    return $error_failed_to_execute_regex
  fi
  return 0
}

function run_loop_regex() {
  local regex_pattern="$1"
  perl -pe "$regex_pattern" -i.orig$i.$j $usage_unit && ((j++))
  if [ "$?" -ne "0" ]; then
    error_log "Failed to execute regex -- $regex_pattern"
    return $error_failed_to_execute_regex
  fi
  return 0
}

function log_failed_unit() {
  failed_units+=("$1")
}

function check_error_and_log() {

  if [ "$?" -ne "0" ]; then
    local failed_unit_id="$1"
    log_failed_unit $failed_unit_id
  fi
}

function final_report() {
  # check if any units failed
  if [ ${#failed_units[@]} -gt 0 ]; then
    error_log "The following units failed:"
    printf '\t%s' "${failed_units[@]}"
    echo -e "\n"
    info_log "run ./convert.sh --unit [ID] for debugging files at $temp_dir"
    echo ""
  else
    echo -e " [${GREEN}SUCCESS${NC}] : All units converted successfully."
    echo -e " [INFO] : JSONs located in: $dest_dir\n"
  fi
  return 0
}


# bp_to_json()
#
# Various regex-ing to change the LUA blueprint files to be JSON format.
# Hard-coded in a couple spots, still working on some better logic to catch
# these couple edge cases.
#
# 3 parameters
#   - $1 - temporary usage directory to work in
#   - $2 - destination directory for the final unit JSON file
#   - $3 - path to the unit blueprint file to convert from
#
function bp_to_json() {
  ########
  # Setup
  #
  # initialize local variables:
  local temp_dir=$1 # location of temporary work
  local dest_dir=$2 # destination of the final JSON file
  local unit=$3 # path to the source blueprint file
  local unit_name=`basename $unit` # get just the ABC1234_unit.bp filename
  local unit_id=`echo $unit_name | perl -pe 's/_unit.bp//'` # strip ABC1234 out of the name
  local usage_unit=$temp_dir/$unit_name # path to the usage blueprint file

  # setup temporary usage folder
  [ ! -d $temp_dir ] && mkdir $temp_dir

  # copy unit file to usage directory
  cp $unit $usage_unit

  # set counter to label temp files for debugging
  i=1
  ########
  # Clean the file of simple issues:
  # 1. remove any \r chars
  run_regex 'tr/\r//d'
  # 2. replace = with :
  run_regex 's/=/:/'
  # 3. replace nil with null
  run_regex 's/:[ ]*nil[ ]*/: null/'
  # 4. remove leading UnitBlueprint on first line
  run_regex 's/^[ ]*UnitBlueprint[ ]+//'
  # 5. remove any double-quotes from strings
  run_regex "s/\"//g"
  # 6. remove any escaped single-quotes from strings (thanks UEL0001 :) )
  run_regex "s#\\\'##g"
  # 7. replace single quotes with doubles
  run_regex "s/[\']/\"/g"
  # 8. replace semi-colons with commas (wtf why, like one case - XES0205 :) )
  run_regex 's/;/,/g'
  # 9. remove all tabs
  run_regex 's/[\t]//g'
  # 10. remove <...> blocks
  run_regex 's/[<][A-Za-z0-9_ ]*[>]//g'
  # 11. quote properties
  run_regex 's/^([ ]*)([A-Za-z_]+)([0-9]*)([A-Za-z_]*)/\1\"\2\3\4\"/'
  # 12 & 13. delete any comments
  run_regex 's/--.*//g'
  run_regex 's/#.*//g'
  # 14. remove blank lines
  run_regex '/^\s*$/d'
  # 15. remove "Sound", unneeded and breaks things
  run_regex 's/:[ ]+Sound[ ]+\{/: \{/'

  ########
  # Format changes to aid in next section
  # 16. remove new-line chars
  run_regex 's/\n//g'

  ########
  # Removing white-space in steps for easier debugging
  # 17.
  run_regex 's/\{[ ]+\"/\{\"/g' # {..."
  run_regex 's/[ ]+\"/\"/g' # ..."
  run_regex 's/[ ]*:[ ]*/:/g' # ...:...
  run_regex 's/,[ ]+\"/,\"/g' # ,..."
  run_regex 's/,[ ]+\}/,\}/g' # ,...}
  # 22.
  run_regex 's/\{[ ]+\{/\{\{/g' # {...{
  run_regex 's/,[ ]+\{/,\{/g' # ,...{
  run_regex 's/\{[ ]+([0-9\-])/\{\1/g' # {...#
  run_regex 's/,[ ]+([0-9\-])/,\1/g' # ,...#
  run_regex 's/\}[ ]+\}/\}\}/g' # }...}
  # 27.
  run_regex 's/\{[ ]+\./\{\./g' # [   .#

  # 28. remove bad commas
  run_regex 's/,\}/\}/g'
  # 29. remove first and last braces (temporary, replaced later)
  #   - helps with array-izing things later
  run_regex 's/^\{(.*)\}$/\1/'

  ########
  # Correct simple arrays to use [] instead of {}:
  # 29. format text arrays
  run_regex 's/\{(\"[A-Za-z0-9_ ,\"\-]+\")\}/\[\1\]/g'
  # 30. format number arrays
  run_regex 's/\{([0-9 ,\.\-]+)\}/\[\1\]/g'
  # 31. correct single-item simple arrays
  run_regex 's/\{([^\{\}:]+?)\}/\[\1\]/g'

  ########
  # Correct number format issues:
  # 32. correct bad format negative numbers (add missing zeroes)
  run_regex 's/[-][\.]/-0\./g'
  # 33. correct bad format positive numbers (add missing zeroes)
  #run_regex 's/([^0-9]|:)[\.]([0-9])/\1[0]\.\2/g'
  run_regex 's/:([\[\{]{1})\.([0-9])/:\1 0\.\2/g'
  # 34. remove unnecessary leading zeros (allows 0.#### values)
  run_regex 's/([:])([0]+)([123456789])/\1\3/g'
  # ##. add a zero to lazy decimal values (ie. .45 should be 0.45)
  run_regex 's/:\.([0-9])/:0\.\1/g' # comment out to flag a couple failures

  ########
  # Handling arrays of complex objects:
  #   - kinda hard-coded as its difficult to use regex to grab the
  #     correct end of the array
  # 35. new-line majority of the first-level attributes to make array-izing easier
  j=1
  for attribute in `cat lib/all_first_level.attributes`; do
    run_loop_regex "s/$attribute/\n$attribute/"
  done
  # increase step counter now that loop is done
  ((i++))
  # 36. enforce the "Weapon" attribute to be array
  run_regex 's/^(\"Weapon\":)\{(.*)\}(,*)$/\1\[\2\]\3/'
  # 37. enforce the "Bones" attribute to be an array, pretty hard-coded
  # the 'else' works just fine for all units except XSL0202, sheesh :)
  #   - identical except for replacings the last 5 }'s
  #     - uses }]}}} instead of }}]}}
  if [ $unit_id = 'XSL0202' ]; then
    run_regex 's/(\"Bones\"[:])([\{]{2})(.*?)([\}]{5})/\1\[\{\3\}\]\}\}\}/g'
  else
    run_regex 's/(\"Bones\"[:])([\{]{2})(.*?)([\}]{5})/\1\[\{\3\}\}\]\}\}/g'
  fi
  # 38. fix any remaining easy-to-catch arrays of objects
  run_regex 's/\{\{(.+?)\}\}/\[\{\1\}\]/g'

  ########
  # Correct intentional breaks, add ID
  #
  # 39. remove newlines again - some line breaks can mess with the mjson.tool
  run_regex 's/\n//g'
  # 40. add blueprint ID to each file
  run_regex "s/^(.*)$/\"BlueprintID\": \"$unit_id\",\1/"
  # 41. replace first and last braces
  run_regex 's/^(.*)$/\{\1\}/'
  # 42. make a copy of final stage for debugging:
  cp $usage_unit $usage_unit.orig$i

  ########
  # Validation, conversion and cleanup
  #
  # 43. validate that the file is JSON, dump it in pretty format to destination
  cat $usage_unit | python -mjson.tool > $dest_dir/$unit_id.json
  if [ "$?" -ne "0" ]; then
    error_log "Failed to validate $unit_id as JSON"
    return $error_failed_to_validate_json
  fi
  # remove temp directory
  rm -rf $temp_dir

  return 0
}

# print_usage()
#
function print_usage() {
    echo ""
    echo "*****************************************************************"
    echo "  convert.sh - Convert FAF blueprint files to JSON"
    echo "  Burke Lougheed - https://github.com/BurkaLurka/faf-unit-converter"
    echo ""
    echo "  Dependencies:"
    echo "    Perl 5.x.x"
    echo "    Python 2.x.x"
    echo "    GitHub repository - https://github.com/FAForever/fa"
    echo ""
    echo "  Usage: ./convert.sh [option value] ..."
    echo ""
    echo "  Options:"
    echo "    -r | --repo [ /path/to/repository ]"
    echo "      Specify local path of /fa repository"
    echo "      Default: $PWD/../fa"
    echo ""
    echo "    -d | --dest [ /path/to/destination ]"
    echo "      Specify local path for final unit JSON files"
    echo "      Default: $PWD/units"
    echo ""
    echo "    -u | --unit [ blueprint ID ]"
    echo "      Specify a unit's ID to convert only that one"
    echo "      Default: All units will be converted"
    echo ""
    echo "    -v | --verbose"
    echo "      Turn on verbose logging"
    echo ""
    echo "    -h | --help"
    echo "      Show this help page"
    echo ""
    echo "  Examples:"
    echo "    ./convert.sh --dest ~/dev/units"
    echo "      Attempts to convert all units and puts final JSONs in ~/dev/units"
    echo ""
    echo "    ./convert.sh --unit URL0001"
    echo "      Will only convert unit URL0001"
    echo ""
    echo "    ./convert.sh -r ~/dev/repos/fa -v"
    echo "      Looks to ~/dev/repos/fa for the FAF repository, converts all units with verbose logging"
    echo ""
    return 0
}


function process_args() {
    local -i argument_count=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -h|--help)
            print_usage
            exit 0 # no error needed
            ;;
        -r|--repo) # repository path flagged, reassign
            if [ -z ${2+"x"} ]; then # ensure a value is provided
              error_log "$1 requires a following value"
              print_usage
              exit $error_bad_parameter # bad parameter usage
            fi
            repo_dir=$2
            shift 2
            ;;
        -d|--dest) # destination path flagged, reassign
            if [ -z ${2+"x"} ]; then # ensure a value is provided
              error_log "$1 requires a following value"
              print_usage
              exit $error_bad_parameter # bad parameter usage
            fi
            dest_dir=$2
            shift 2
            ;;
        -u|--unit) # single unit flagged, reassign
            if [ -z ${2+"x"} ]; then # ensure a value is provided
              error_log "$1 requires a following value"
              print_usage
              exit $error_bad_parameter # bad parameter usage
            fi
            single_unit=$2
            shift 2
            ;;
        -v|--verbose)
            verbose_logging="true"
            info_log "Verbose logging enabled"
            shift 1
            ;;
        *)
            error_log "Unexpected parameter set -  \"$1\""
            print_usage
            exit $error_unexpected_parameter # unexpected parameter flagged
        esac
    done
    return 0
}
