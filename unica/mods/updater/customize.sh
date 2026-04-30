SET_PROP "system" "ro.artisanrom.version" "$UPDATER_VERSION"
SET_PROP "system" "ro.artisanrom.target" "$TARGET_CODENAME"

ADD_TO_WORK_DIR "$MODPATH" "system" "."

DECODE_APK "system" "system/priv-app/ArtisanUpdater/ArtisanUpdater.apk"
