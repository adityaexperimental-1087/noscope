SET_PROP "system" "ro.artisanrom.version" "$UPDATER_VERSION"
SET_PROP "system" "ro.artisanrom.target" "$TARGET_CODENAME"

ADD_TO_WORK_DIR "$MODPATH" "system" "." 0 0 755 "u:object_r:system_file:s0"
