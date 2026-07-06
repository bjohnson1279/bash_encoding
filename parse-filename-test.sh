#!/bin/bash
test_sed() {
    local show_name="Show.Name - "
    echo "Original: '$show_name'"

    local show_name_old=$(printf "%s\n" "$show_name" | sed -E 's/(\.|_)/ /g' | sed -E 's/[[:space:]]+$//' | sed -E 's/^[[:space:]]+//')
    show_name_old=$(printf "%s\n" "$show_name_old" | sed -E 's/( -)+$//')
    echo "Old: '$show_name_old'"

    local show_name_new=$(printf "%s\n" "$show_name" | sed -E 's/(\.|_)/ /g; s/[[:space:]]+$//; s/^[[:space:]]+//; s/( -)+$//')
    echo "New: '$show_name_new'"
}
test_sed
