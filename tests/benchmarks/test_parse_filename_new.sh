#!/bin/bash
chmod +x parse-filename_new.sh
# Check if tests pass
sed 's/.\/parse-filename.sh/.\/parse-filename_new.sh/g' test_parse_filename.sh > test_parse_filename_tmp.sh
chmod +x test_parse_filename_tmp.sh
./test_parse_filename_tmp.sh
