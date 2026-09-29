with open("encode-all.sh", "r") as f:
    data = f.read()

old_show = """    PARSED_SHOW_NAME="${show_raw//[._]/ }"
    PARSED_SHOW_NAME="${PARSED_SHOW_NAME#"${PARSED_SHOW_NAME%%[! ]*}"}"
    PARSED_SHOW_NAME="${PARSED_SHOW_NAME%"${PARSED_SHOW_NAME##*[! ]}"}"
    PARSED_SHOW_NAME="${PARSED_SHOW_NAME%" -"}"
    PARSED_SHOW_NAME="${PARSED_SHOW_NAME%"${PARSED_SHOW_NAME##*[! ]}"}"
"""
new_show = """    # ⚡ Bolt Optimization: Replace sequential space stripping with faster negated glob stripping
    # Trims trailing space and hyphens in fewer native operations
    PARSED_SHOW_NAME="${show_raw//[._]/ }"
    PARSED_SHOW_NAME="${PARSED_SHOW_NAME#"${PARSED_SHOW_NAME%%[! ]*}"}"
    PARSED_SHOW_NAME="${PARSED_SHOW_NAME%"${PARSED_SHOW_NAME##*[!._ -]}"}"
"""

old_title = """    PARSED_EPISODE_TITLE="${title_raw//[._]/ }"
    PARSED_EPISODE_TITLE="${PARSED_EPISODE_TITLE#"${PARSED_EPISODE_TITLE%%[! ]*}"}"
    PARSED_EPISODE_TITLE="${PARSED_EPISODE_TITLE%"${PARSED_EPISODE_TITLE##*[! ]}"}"
    PARSED_EPISODE_TITLE="${PARSED_EPISODE_TITLE%" -"}"
    PARSED_EPISODE_TITLE="${PARSED_EPISODE_TITLE%"${PARSED_EPISODE_TITLE##*[! ]}"}"
"""
new_title = """    PARSED_EPISODE_TITLE="${title_raw//[._]/ }"
    PARSED_EPISODE_TITLE="${PARSED_EPISODE_TITLE#"${PARSED_EPISODE_TITLE%%[! ]*}"}"
    PARSED_EPISODE_TITLE="${PARSED_EPISODE_TITLE%"${PARSED_EPISODE_TITLE##*[!._ -]}"}"
"""

if old_show in data:
    data = data.replace(old_show, new_show)
    print("Replaced old_show")
else:
    print("old_show not found")

if old_title in data:
    data = data.replace(old_title, new_title)
    print("Replaced old_title")
else:
    print("old_title not found")

with open("encode-all.sh", "w") as f:
    f.write(data)
