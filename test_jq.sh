show_name="Test Show"
season_num="01"
episode_num="02"
episode_title="Test \"Episode\""

json_output=$(jq -n \
    --arg show_name "$show_name" \
    --arg season "$season_num" \
    --arg episode "$episode_num" \
    --arg title "$episode_title" \
    '{
        "show_name": $show_name,
        "season": $season,
        "episode": $episode,
        "title": $title
    }')
echo "$json_output"
