SKIPUNZIP=1

# Set ArtisanROM updater flags
SET_PROP "system" "ro.artisanrom.version" "$UPDATER_VERSION"
SET_PROP "system" "ro.artisanrom.target" "$TARGET_CODENAME"

if ! $ROM_IS_OFFICIAL; then
    LOG "Build is not official. Skipping"
    return 0
fi

ADD_TO_WORK_DIR "$MODPATH" "system" "."
