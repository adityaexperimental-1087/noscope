SKIPUNZIP=1

# Set MonsterROM updater flags. Keep ArtisanROM aliases because the
# bundled updater package still reads them internally.
MONSTER_UPDATER_VERSION="${UPDATER_VERSION:-$ROM_VERSION}"
SET_PROP "system" "ro.monsterrom.version" "$MONSTER_UPDATER_VERSION"
SET_PROP "system" "ro.monsterrom.target" "$TARGET_CODENAME"
SET_PROP "system" "ro.artisanrom.version" "$MONSTER_UPDATER_VERSION"
SET_PROP "system" "ro.artisanrom.target" "$TARGET_CODENAME"

if ! $ROM_IS_OFFICIAL; then
    LOG "- Build is not official. Installing updater anyway"
fi

ADD_TO_WORK_DIR "$MODPATH" "system" "."

unset MONSTER_UPDATER_VERSION
