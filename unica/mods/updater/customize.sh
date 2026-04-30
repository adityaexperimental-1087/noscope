SKIPUNZIP=1

MONSTER_UPDATER_VERSION="$(GET_PROP "system" "ro.unica.version")"
if [ ! "$MONSTER_UPDATER_VERSION" ]; then
    MONSTER_UPDATER_VERSION="${ROM_VERSION:-$UPDATER_VERSION}"
fi
if [ ! "$MONSTER_UPDATER_VERSION" ]; then
    ABORT "Unable to determine MonsterROM updater version"
fi

MONSTER_UPDATER_TARGET="${TARGET_CODENAME:-$(GET_PROP "system" "ro.product.device")}"
if [ ! "$MONSTER_UPDATER_TARGET" ]; then
    ABORT "Unable to determine MonsterROM updater target"
fi

SET_PROP "system" "ro.monsterrom.version" "$MONSTER_UPDATER_VERSION"
SET_PROP "system" "ro.monsterrom.target" "$MONSTER_UPDATER_TARGET"
SET_PROP "system" "ro.artisanrom.version" "$MONSTER_UPDATER_VERSION"
SET_PROP "system" "ro.artisanrom.target" "$MONSTER_UPDATER_TARGET"

if ! $ROM_IS_OFFICIAL; then
    LOG "- Build is not official. Installing updater anyway"
fi

ADD_TO_WORK_DIR "$MODPATH" "system" "."

if [ ! -f "$WORK_DIR/system/system/priv-app/ArtisanUpdater/ArtisanUpdater.apk" ]; then
    ABORT "Failed to install MonsterROM updater APK"
fi

unset MONSTER_UPDATER_VERSION MONSTER_UPDATER_TARGET
