#!/bin/bash

# Original Regex 1 from the script
R1='^(.*)\ \(([0-9]{4})\)[._\ -]+[Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})[._\ -]+(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$'
# Original Regex 2 from the script
R2='^(.*)\ \(([0-9]{4})\)[._\ -]+[Ss]([0-9]{1,2})[._\ -]*[Ee]([0-9]{1,2})[._\ -]+(.*)\ \([0-9]{4}-[0-9]{2}-[0-9]{2}.*\)$'

if [ "$R1" = "$R2" ]; then
    echo "R1 and R2 are identical."
else
    echo "R1 and R2 are different."
fi
