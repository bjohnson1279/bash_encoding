#!/bin/bash
var='foo\bar'
val="${var//\\/\\\\}"
echo "Test 1: $val"
val="${var//\\\\/\\\\\\\\}"
echo "Test 2: $val"

var2='foo\bar'
val2="${var2//\\\\/\\\\\\\\}"
echo "Test 3: $val2"
