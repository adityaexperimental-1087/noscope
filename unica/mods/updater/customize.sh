SKIPUNZIP=1

# Set ArtisanROM updater flags
ARTISAN_UPDATER_VERSION="${UPDATER_VERSION:-$ROM_VERSION}"
SET_PROP "system" "ro.artisanrom.version" "$ARTISAN_UPDATER_VERSION"
SET_PROP "system" "ro.artisanrom.target" "$TARGET_CODENAME"

if ! $ROM_IS_OFFICIAL; then
    LOG "- Build is not official. Installing updater anyway"
fi

ADD_TO_WORK_DIR "$MODPATH" "system" "."

unset ARTISAN_UPDATER_VERSION
