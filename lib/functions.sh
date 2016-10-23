#!/bin/bash

##################
# Library functions for use in the converter.sh script
##################

# convertBlueprintToJSON()
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
function convertBlueprintToJSON() {
  ########
  # Setup
  #
  # initialize local variables:
  local usage_dir=$1 # location of temporary work
  local dest_dir=$2 # destination of the final JSON file
  local unit=$3 # path to the source blueprint file
  local unit_name=`basename $unit` # get just the ABC1234_unit.bp filename
  local unit_id=`echo $unit_name | sed 's/_unit.bp//'` # strip ABC1234 out of the name
  local usage_unit=$usage_dir/$unit_name # path to the usage blueprint file
  
  # setup temporary usage folder
  [ ! -d $usage_dir ] && mkdir $usage_dir
  
  # copy unit file to usage directory
  cp $unit $usage_unit
  
  ########
  # Clean the file of simple issues:
  #
  # remove any \r chars
  sed -re 's/\r//' -i $usage_unit
  # replace = with :
  sed -re 's/=/:/' -i $usage_unit
  # replace nil with null
  sed -re 's/:[ ]*nil[ ]*/: null/' -i $usage_unit
  # remove leading UnitBlueprint on first line
  sed -re '1s/[A-Za-z ]+//' -i $usage_unit 
  # remove any double-quotes from strings
  sed "s/\"//g" -i $usage_unit
  # remove any escaped single-quotes from strings (thanks UEL0001 :) )
  sed "s#\\\'##g" -i $usage_unit
  # replace single quotes with doubles
  sed -re "s/[\']/\"/g" -i $usage_unit 
  # replace semi-colons with commas (wtf why, like one case - XES0205 :) )
  sed -re 's/;/,/g' -i $usage_unit
  # remove all tabs
  sed -re 's/[\t]//g' -i $usage_unit
  # remove <...> blocks
  sed -re 's/[<][A-Za-z0-9_ ]*[>]//g' -i $usage_unit
  # quote properties
  sed -re 's/^([ ]*)([A-Za-z_]+)([0-9]*)([A-Za-z_]*)/\1\"\2\3\4\"/' -i $usage_unit
  # delete any comments
  sed -re 's/--.*//g' -i $usage_unit
  sed -re 's/#.*//g' -i $usage_unit
  # remove blank lines
  sed -re '/^\s*$/d' -i $usage_unit
  # remove "Sound", unneeded and breaks things 
  sed -re 's/:[ ]+Sound[ ]+\{/: \{/' -i $usage_unit
  
  ########
  # Format changes to aid in next section:
  #
  # remove new-line chars
  sed ':a;N;$!ba;s/\n//g' -i $usage_unit
  # remove white-space
  sed -re 's/\{[ ]+\"/\{\"/g' -i $usage_unit # {..."
  sed -re 's/[ ]+\"/\"/g' -i $usage_unit # ..."
  sed -re 's/[ ]*:[ ]*/:/g' -i $usage_unit # ...:...
  sed -re 's/,[ ]+\"/,\"/g' -i $usage_unit # ,..."
  sed -re 's/,[ ]+\}/,\}/g' -i $usage_unit # ,...} 
  sed -re 's/\{[ ]+\{/\{\{/g' -i $usage_unit # {...{
  sed -re 's/,[ ]+\{/,\{/g' -i $usage_unit # ,...{
  sed -re 's/\{[ ]+([0-9\-])/\{\1/g' -i $usage_unit # {...#
  sed -re 's/,[ ]+([0-9\-])/,\1/g' -i $usage_unit # ,...#
  sed -re 's/\}[ ]+\}/\}\}/g' -i $usage_unit # }...}
  # remove bad commas
  sed -re 's/,\}/\}/g' -i $usage_unit
  # remove first and last braces (temporary, replaced later)
  #   - helps with array-izing things later
  sed -re 's/^\{(.*)\}$/\1/' -i $usage_unit
  
  ########
  # Correct simple arrays to use [] instead of {}:
  #
  # format text arrays
  sed -re 's/\{(\"[A-Za-z0-9_ ,\"\-]+\")\}/\[\1\]/g' -i $usage_unit
  # format number arrays
  sed -re 's/\{([0-9 ,\.\-]+)\}/\[\1\]/g' -i $usage_unit
  # correct single-item simple arrays
  perl -p -i -e 's/\{([^\{\}:]+?)\}/\[\1\]/g' $usage_unit
  
  ########
  # Correct number format issues:
  #
  # correct bad format negative numbers (add missing zeroes)
  sed -re 's/[-][\.]/-0\./g' -i $usage_unit
  # correct bad format positive numbers (add missing zeroes)
  sed -re 's/([^0-9])[\.]([0-9])/\10\.\2/g' -i $usage_unit
  # remove unnecessary leading zeros (allows 0.#### values)
  sed -re 's/([:])([0]+)([123456789])/\1\3/g' -i $usage_unit
  
  ########
  # Handling arrays of complex objects:
  #   - kinda hard-coded as its difficult to use regex to grab the 
  #     correct end of the array
  # new-line each of the first-level attributes to make array-izing easier
  for attribute in `cat lib/all_first_level.attributes`; do
    sed -re "s/$attribute/\n$attribute/" -i $usage_unit
  done
  # enforce the "Weapon" attribute to be array
  sed -re 's/^(\"Weapon\":)\{(.*)\}(,*)$/\1\[\2\]\3/' -i $usage_unit
  # enforce the "Bones" attribute to be an array, pretty hard-coded
  # the 'else' works just fine for all units except XSL0202, sheesh :)
  #   - identical except for replacings the last 5 }'s 
  #     - uses }]}}} instead of }}]}}
  if [ $unit_id = 'XSL0202' ]; then
    perl -p -i -e 's/(\"Bones\"[:])([\{]{2})(.*?)([\}]{5})/\1\[\{\3\}\]\}\}\}/g' $usage_unit 
  else  
    perl -p -i -e 's/(\"Bones\"[:])([\{]{2})(.*?)([\}]{5})/\1\[\{\3\}\}\]\}\}/g' $usage_unit 
  fi
  # fix any remaining easy-to-catch arrays of objects 
  perl -p -i -e 's/\{\{(.+?)\}\}/\[\{\1\}\]/g' $usage_unit

  ########
  # Correct intentional breaks, add ID
  #
  # remove newlines again - some line breaks can mess with the mjson.tool
  sed ':a;N;$!ba;s/\n//g' -i $usage_unit
  # add blueprint ID to each file
  sed -re "s/^(.*)$/\"BlueprintID\": \"$unit_id\",\1/" -i $usage_unit
  # replace first and last braces
  sed -re 's/^(.*)$/\{\1\}/' -i $usage_unit

  ########
  # Validation, conversion and cleanup
  #
  # validate that the file is JSON, dump it in pretty format to destination
  cat $usage_unit | python -mjson.tool > $dest_dir/$unit_id.json
  # remove usage directory
  rm -rf $usage_dir
}
