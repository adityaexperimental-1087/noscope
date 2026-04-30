if [ ! "$(GET_PROP "system" "ro.unica.version")" ]; then
    SET_PROP "system" "ro.unica.version" "$ROM_VERSION"
fi

SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali/android/app/Instrumentation.smali" "replace" \
    'newApplication(Ljava/lang/Class;Landroid/content/Context;)Landroid/app/Application;' \
    'invoke-virtual {p0, p1}, Landroid/app/Application;->attach(Landroid/content/Context;)V' \
    '    invoke-virtual {p0, p1}, Landroid/app/Application;->attach(Landroid/content/Context;)V\n\n    invoke-static {p1}, Lio/mesalabs/unica/SamsungPropsHooks;->init(Landroid/content/Context;)V' \
    > /dev/null
SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali/android/app/Instrumentation.smali" "replace" \
    'newApplication(Ljava/lang/ClassLoader;Ljava/lang/String;Landroid/content/Context;)Landroid/app/Application;' \
    'invoke-virtual {p0, p3}, Landroid/app/Application;->attach(Landroid/content/Context;)V' \
    '    invoke-virtual {p0, p3}, Landroid/app/Application;->attach(Landroid/content/Context;)V\n\n    invoke-static {p3}, Lio/mesalabs/unica/SamsungPropsHooks;->init(Landroid/content/Context;)V' \
    > /dev/null

DECODE_APK "system" "system/framework/framework.jar"
FRAMEWORK_JAR_DIR="$APKTOOL_DIR/system/framework/framework.jar"
ASKS_MANAGER_PATH="$(find "$FRAMEWORK_JAR_DIR" -type f -path "*/android/content/pm/ASKSManager.smali" | sort | head -n 1)"
if [ "$ASKS_MANAGER_PATH" ] && ! grep -q -F "UN1CA: honor ASKS toggle" "$ASKS_MANAGER_PATH"; then
    LOG "- Patching \"${ASKS_MANAGER_PATH#$FRAMEWORK_JAR_DIR/}\" in /system/system/framework/framework.jar"
    perl -0pi -e '
        s{(^\.method[^\n]* hasBlockPolicy\(\)Z\n)\s+\.locals \d+\n.*?^\.end method}
         {$1."    .locals 2\n\n    # UN1CA: honor ASKS toggle\n    const-string v0, \"persist.sys.unica.asks\"\n\n    const/4 v1, 0x1\n\n    invoke-static {v0, v1}, Landroid/os/SemSystemProperties;->getBoolean(Ljava/lang/String;Z)Z\n\n    move-result v0\n\n    if-eqz v0, :cond_0\n\n    sget-boolean v0, Landroid/content/pm/ASKSManager;->hasBlockedPolicy:Z\n\n    return v0\n\n    :cond_0\n    const/4 v0, 0x0\n\n    return v0\n.end method"}mse;
        s{(^\.method[^\n]* isBlockTarget\(ILjava/lang/String;\)Z\n\s+\.locals \d+\n)}
         {$1."\n    # UN1CA: honor ASKS toggle\n    const-string v0, \"persist.sys.unica.asks\"\n\n    const/4 v1, 0x1\n\n    invoke-static {v0, v1}, Landroid/os/SemSystemProperties;->getBoolean(Ljava/lang/String;Z)Z\n\n    move-result v0\n\n    if-nez v0, :unica_asks_enabled_block\n\n    const/4 v0, 0x0\n\n    return v0\n\n    :unica_asks_enabled_block\n"}mse;
        s{(^\.method[^\n]* isRestrictedTarget\(Ljava/lang/String;Ljava/lang/String;\)Z\n\s+\.locals \d+\n)}
         {$1."\n    # UN1CA: honor ASKS toggle\n    const-string v0, \"persist.sys.unica.asks\"\n\n    const/4 v1, 0x1\n\n    invoke-static {v0, v1}, Landroid/os/SemSystemProperties;->getBoolean(Ljava/lang/String;Z)Z\n\n    move-result v0\n\n    if-nez v0, :unica_asks_enabled_restricted\n\n    const/4 v0, 0x0\n\n    return v0\n\n    :unica_asks_enabled_restricted\n"}mse;
    ' "$ASKS_MANAGER_PATH"
    grep -q -F "UN1CA: honor ASKS toggle" "$ASKS_MANAGER_PATH" || ABORT "Failed to patch ASKSManager"
fi

LOG "- Allowing UN1CA Settings to write runtime props"
UNICA_SYSTEM_PROPERTY_CONTEXTS="$WORK_DIR/system/system/etc/selinux/plat_property_contexts"
UNICA_SYSTEM_EXT_PROPERTY_CONTEXTS=""
UNICA_SYSTEM_EXT_SEPOLICY=""
for UNICA_SELINUX_DIR in \
        "$WORK_DIR/system_ext/etc/selinux" \
        "$WORK_DIR/system/system_ext/etc/selinux" \
        "$WORK_DIR/system/system/system_ext/etc/selinux"; do
    if [ -f "$UNICA_SELINUX_DIR/system_ext_property_contexts" ]; then
        UNICA_SYSTEM_EXT_PROPERTY_CONTEXTS="$UNICA_SELINUX_DIR/system_ext_property_contexts"
    fi
    if [ -f "$UNICA_SELINUX_DIR/system_ext_sepolicy.cil" ]; then
        UNICA_SYSTEM_EXT_SEPOLICY="$UNICA_SELINUX_DIR/system_ext_sepolicy.cil"
    fi
    if [ "$UNICA_SYSTEM_EXT_PROPERTY_CONTEXTS" ] && [ "$UNICA_SYSTEM_EXT_SEPOLICY" ]; then
        break
    fi
done

if [ "$UNICA_SYSTEM_EXT_PROPERTY_CONTEXTS" ]; then
    sed -i '/^persist\.sys\.unica\.[[:space:]]/d' "$UNICA_SYSTEM_EXT_PROPERTY_CONTEXTS"
fi

if [ -f "$UNICA_SYSTEM_PROPERTY_CONTEXTS" ]; then
    if ! grep -q -F "persist.sys.unica." "$UNICA_SYSTEM_PROPERTY_CONTEXTS"; then
        if [ "$UNICA_SYSTEM_EXT_SEPOLICY" ] && grep -q -F "system_ucm_prop" "$UNICA_SYSTEM_EXT_SEPOLICY"; then
            sed -i '/^persist\.sys\.[[:space:]]/i persist.sys.unica.                   u:object_r:system_ucm_prop:s0' "$UNICA_SYSTEM_PROPERTY_CONTEXTS"
        else
            LOG "\033[0;33m! system_ucm_prop label not found, skipping UN1CA property context\033[0m"
        fi
    fi
else
    LOG "\033[0;33m! platform property contexts not found, skipping UN1CA property context\033[0m"
fi

if [ "$UNICA_SYSTEM_EXT_SEPOLICY" ]; then
    for UNICA_PROP_DOMAIN in system_app platform_app priv_app; do
        grep -Eq "(^|[[:space:](])${UNICA_PROP_DOMAIN}([[:space:])]|$)" "$UNICA_SYSTEM_EXT_SEPOLICY" || continue

        UNICA_ALLOW_RULE="(allow $UNICA_PROP_DOMAIN system_ucm_prop (property_service (set)))"
        grep -q -F "$UNICA_ALLOW_RULE" "$UNICA_SYSTEM_EXT_SEPOLICY" || echo "$UNICA_ALLOW_RULE" >> "$UNICA_SYSTEM_EXT_SEPOLICY"

        UNICA_ALLOW_RULE="(allow $UNICA_PROP_DOMAIN system_ucm_prop (file (read getattr map open)))"
        grep -q -F "$UNICA_ALLOW_RULE" "$UNICA_SYSTEM_EXT_SEPOLICY" || echo "$UNICA_ALLOW_RULE" >> "$UNICA_SYSTEM_EXT_SEPOLICY"
    done

    for UNICA_PROP_DOMAIN in system_server; do
        grep -Eq "(^|[[:space:](])${UNICA_PROP_DOMAIN}([[:space:])]|$)" "$UNICA_SYSTEM_EXT_SEPOLICY" || continue

        UNICA_ALLOW_RULE="(allow $UNICA_PROP_DOMAIN system_ucm_prop (file (read getattr map open)))"
        grep -q -F "$UNICA_ALLOW_RULE" "$UNICA_SYSTEM_EXT_SEPOLICY" || echo "$UNICA_ALLOW_RULE" >> "$UNICA_SYSTEM_EXT_SEPOLICY"
    done
else
    LOG "\033[0;33m! system_ext sepolicy not found, skipping UN1CA property allow rules\033[0m"
fi

DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk"
SECSETTINGS_APK_DIR="$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk"

# Disable stock OTA references
if [ ! -f "$WORK_DIR/system/system/priv-app/ChoiDujour/ChoiDujour.apk" ]; then
    SOFTWARE_UPDATE_UTILS_PATH="$(find "$SECSETTINGS_APK_DIR" -type f -path "*/com/samsung/android/settings/softwareupdate/SoftwareUpdateUtils.smali" | sort | head -n 1)"
    if [ ! "$SOFTWARE_UPDATE_UTILS_PATH" ]; then
        ABORT "SoftwareUpdateUtils.smali not found in SecSettings"
    fi
    SOFTWARE_UPDATE_UTILS_SMALI="${SOFTWARE_UPDATE_UTILS_PATH#$SECSETTINGS_APK_DIR/}"

    SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
        "$SOFTWARE_UPDATE_UTILS_SMALI" "return" \
        'isOTAUpgradeAllowed(Landroid/content/Context;)Z' \
        'false'
fi

# Always show One UI minor version
ONEUI_VERSION_CONTROLLER_PATH="$(find "$SECSETTINGS_APK_DIR" -type f -path "*/com/samsung/android/settings/deviceinfo/softwareinfo/OneUIVersionPreferenceController.smali" | sort | head -n 1)"
if [ ! "$ONEUI_VERSION_CONTROLLER_PATH" ]; then
    ABORT "OneUIVersionPreferenceController.smali not found in SecSettings"
fi
ONEUI_VERSION_CONTROLLER_SMALI="${ONEUI_VERSION_CONTROLLER_PATH#$SECSETTINGS_APK_DIR/}"

SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "$ONEUI_VERSION_CONTROLLER_SMALI" "replace" \
    'isDeviceWithMicroVersion()Z' \
    'move-result p0' \
    'const/4 p0, 0x1'

# Show real device model number
MODEL_NAME_GETTER_PATH="$(find "$SECSETTINGS_APK_DIR" -type f -path "*/com/samsung/android/settings/deviceinfo/aboutphone/ModelNameGetter.smali" | sort | head -n 1)"
if [ ! "$MODEL_NAME_GETTER_PATH" ]; then
    ABORT "ModelNameGetter.smali not found in SecSettings"
fi
MODEL_NAME_GETTER_SMALI="${MODEL_NAME_GETTER_PATH#$SECSETTINGS_APK_DIR/}"

SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "$MODEL_NAME_GETTER_SMALI" "replace" \
    'getModelName()Ljava/lang/String;' \
    'ro.product.model' \
    'ro.boot.em.model'

LOG_STEP_IN "- Adding UN1CA Settings"

# Dynamically patch SecSettings
# - Add missing/non-xml files in place
# - Patch existing files
#   - Use the first line of the file to tell sed how to apply the rest of the content
#   - Exception made for files under *res/values* where the "resources" tag gets nuked
while IFS= read -r f; do
    f="${f//$MODPATH\/SecSettings.apk\//}"

    if [ ! -f "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f" ] || \
            [[ "$f" != *".xml" ]]; then
        LOG "- Adding \"$f\" to /system/system/priv-app/SecSettings.apk"
        EVAL "mkdir -p \"$(dirname "$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f")\""
        EVAL "cp -a \"$MODPATH/SecSettings.apk/${f//\$/\\$}\" \"$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/${f//\$/\\$}\""
    else
        LOG "- Patching \"$f\" in /system/system/priv-app/SecSettings.apk"
        if [[ "$f" == *"res/values"* ]]; then
            PATCH_INST="/<\/resources>/i"
            CONTENT="$(sed -e "/?xml/d" -e "/resources>/d" "$MODPATH/SecSettings.apk/$f")"
        else
            PATCH_INST="$(head -n 1 "$MODPATH/SecSettings.apk/$f")"
            CONTENT="$(tail -n +2 "$MODPATH/SecSettings.apk/$f")"
        fi
        CONTENT="$(sed -e "s/\"/\\\\\"/g" -e "s/\\$/\\\\$/g" -e "s/ /\\\ /g" -e "s/\\\\n/\\\\\\\\\n/g" <<< "$CONTENT")"
        CONTENT="$(sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g' <<< "$CONTENT")"
        EVAL "sed -i \"$PATCH_INST $CONTENT\" \"$APKTOOL_DIR/system/priv-app/SecSettings/SecSettings.apk/$f\""
    fi
done < <(find "$MODPATH/SecSettings.apk" -type f)

# Mark UN1CA Settings fragments as "valid"
_ADD_VALID_SETTINGS_FRAGMENT()
{
    local FRAGMENT="$1"
    local SMALI_PATH="$2"
    local BEFORE
    local AFTER

    if grep -q -F "\"$FRAGMENT\"" "$SMALI_PATH"; then
        LOG "\033[0;33m! Settings fragment already valid: $FRAGMENT\033[0m"
        return 0
    fi

    BEFORE="$(sha1sum "$SMALI_PATH")"
    SETTINGS_FRAGMENT="$FRAGMENT" perl -0pi -e 'my $fragment = $ENV{"SETTINGS_FRAGMENT"}; my $done = 0; s{([ \t]*)filled-new-array/range \{v1 \.\. v(\d+)\}, \[Ljava/lang/String;\n\n[ \t]*move-result-object v0\n\n[ \t]*sput-object v0, Lcom/android/settings/core/gateway/SettingsGateway;->SAMSUNG_ENTRY_FRAGMENTS:\[Ljava/lang/String;}{if ($done) { $& } else { $done = 1; $1."const-string v".($2 + 1).", \"$fragment\"\n\n".$1."filled-new-array/range {v1 .. v".($2 + 1)."}, [Ljava/lang/String;\n\n".$1."move-result-object v0\n\n".$1."sput-object v0, Lcom/android/settings/core/gateway/SettingsGateway;->SAMSUNG_ENTRY_FRAGMENTS:[Ljava/lang/String;" }}egs' "$SMALI_PATH"
    AFTER="$(sha1sum "$SMALI_PATH")"

    if [[ "$BEFORE" == "$AFTER" ]]; then
        ABORT "Failed to add Settings fragment to SettingsGateway: $FRAGMENT"
    fi

    ADDED_SETTINGS_FRAGMENTS=$((ADDED_SETTINGS_FRAGMENTS + 1))
}

_BUMP_VALID_SETTINGS_LIMIT()
{
    local COUNT="$1"
    local SMALI_PATH="$2"
    local BEFORE
    local AFTER

    [ "$COUNT" -eq 0 ] && return 0

    BEFORE="$(sha1sum "$SMALI_PATH")"
    SETTINGS_FRAGMENT_COUNT="$COUNT" perl -0pi -e 'my $count = $ENV{"SETTINGS_FRAGMENT_COUNT"}; my $done = 0; s{(SAMSUNG_ENTRY_FRAGMENTS:\[Ljava/lang/String;\n\n[ \t]*const/16 v2, 0x)([0-9a-fA-F]+)}{if ($done) { $& } else { $done = 1; $1.sprintf("%x", hex($2) + $count) }}eg' "$SMALI_PATH"
    AFTER="$(sha1sum "$SMALI_PATH")"

    if [[ "$BEFORE" == "$AFTER" ]]; then
        ABORT "Failed to bump SettingsActivity valid fragment limit"
    fi
}

SETTINGS_GATEWAY_PATH="$(find "$SECSETTINGS_APK_DIR" -type f -path "*/com/android/settings/core/gateway/SettingsGateway.smali" | sort | head -n 1)"
SETTINGS_ACTIVITY_PATH="$(find "$SECSETTINGS_APK_DIR" -type f -path "*/com/android/settings/SettingsActivity.smali" | sort | head -n 1)"

if [ ! "$SETTINGS_GATEWAY_PATH" ]; then
    ABORT "SettingsGateway.smali not found in SecSettings"
fi

if [ ! "$SETTINGS_ACTIVITY_PATH" ]; then
    ABORT "SettingsActivity.smali not found in SecSettings"
fi

LOG "- Patching \"${SETTINGS_GATEWAY_PATH#$SECSETTINGS_APK_DIR/}\" in /system/system/priv-app/SecSettings.apk"
ADDED_SETTINGS_FRAGMENTS=0
_ADD_VALID_SETTINGS_FRAGMENT "io.mesalabs.unica.settings.UnicaSettingsFragment" "$SETTINGS_GATEWAY_PATH"
_ADD_VALID_SETTINGS_FRAGMENT "io.mesalabs.unica.settings.extra.ExtraSettingsFragment" "$SETTINGS_GATEWAY_PATH"
_ADD_VALID_SETTINGS_FRAGMENT "io.mesalabs.unica.settings.hma.HideMyApplistFragment" "$SETTINGS_GATEWAY_PATH"
_ADD_VALID_SETTINGS_FRAGMENT "io.mesalabs.unica.settings.spoof.HideDeveloperStatusFragment" "$SETTINGS_GATEWAY_PATH"
_ADD_VALID_SETTINGS_FRAGMENT "io.mesalabs.unica.settings.spoof.SpoofSettingsFragment" "$SETTINGS_GATEWAY_PATH"
_ADD_VALID_SETTINGS_FRAGMENT "io.mesalabs.unica.settings.ui.UISettingsFragment" "$SETTINGS_GATEWAY_PATH"

LOG "- Patching \"${SETTINGS_ACTIVITY_PATH#$SECSETTINGS_APK_DIR/}\" in /system/system/priv-app/SecSettings.apk"
_BUMP_VALID_SETTINGS_LIMIT "$ADDED_SETTINGS_FRAGMENTS" "$SETTINGS_ACTIVITY_PATH"

# Add UN1CA Settings SearchIndexDataProvider(s)
_ADD_SEARCH_INDEX_PROVIDER()
{
    local FRAGMENT="$1"
    local SMALI_PATH="$2"
    local BEFORE
    local AFTER

    if grep -q -F "L$FRAGMENT;->SEARCH_INDEX_DATA_PROVIDER" "$SMALI_PATH"; then
        LOG "\033[0;33m! Search index provider already present: $FRAGMENT\033[0m"
        return 0
    fi

    BEFORE="$(sha1sum "$SMALI_PATH")"
    printf -v SETTINGS_SEARCH_BLOCK \
'    new-instance v0, Lcom/android/settingslib/search/SearchIndexableData;\n\n    const-class v1, L%s;\n\n    sget-object v2, L%s;->SEARCH_INDEX_DATA_PROVIDER:Lcom/android/settings/search/BaseSearchIndexProvider;\n\n    invoke-direct {v0, v1, v2}, Lcom/android/settingslib/search/SearchIndexableData;-><init>(Ljava/lang/Class;Lcom/android/settingslib/search/Indexable$SearchIndexProvider;)V\n\n    invoke-virtual {p0, v0}, Lcom/android/settingslib/search/SearchIndexableResourcesBase;->addIndex(Lcom/android/settingslib/search/SearchIndexableData;)V\n\n' \
        "$FRAGMENT" "$FRAGMENT"
    SETTINGS_SEARCH_BLOCK="$SETTINGS_SEARCH_BLOCK" perl -0pi -e 'my $block = $ENV{"SETTINGS_SEARCH_BLOCK"}; my $done = 0; s{(\n[ \t]*return-object p0\n\.end method)}{if ($done) { $& } else { $done = 1; "\n".$block.$1 }}e' "$SMALI_PATH"
    AFTER="$(sha1sum "$SMALI_PATH")"

    if [[ "$BEFORE" == "$AFTER" ]] || ! grep -q -F "L$FRAGMENT;->SEARCH_INDEX_DATA_PROVIDER" "$SMALI_PATH"; then
        ABORT "Failed to add Settings search index provider: $FRAGMENT"
    fi
}

SEARCH_PROVIDER_PATH="$(find "$SECSETTINGS_APK_DIR" -type f -path "*/com/android/settings/search/SearchFeatureProviderImpl\$\$ExternalSyntheticLambda0.smali" | sort | head -n 1)"

if [ ! "$SEARCH_PROVIDER_PATH" ]; then
    ABORT "SearchFeatureProviderImpl search provider initializer not found in SecSettings"
fi

LOG "- Patching \"${SEARCH_PROVIDER_PATH#$SECSETTINGS_APK_DIR/}\" in /system/system/priv-app/SecSettings.apk"
_ADD_SEARCH_INDEX_PROVIDER "io/mesalabs/unica/settings/UnicaSettingsFragment" "$SEARCH_PROVIDER_PATH"
_ADD_SEARCH_INDEX_PROVIDER "io/mesalabs/unica/settings/extra/ExtraSettingsFragment" "$SEARCH_PROVIDER_PATH"
_ADD_SEARCH_INDEX_PROVIDER "io/mesalabs/unica/settings/spoof/SpoofSettingsFragment" "$SEARCH_PROVIDER_PATH"
_ADD_SEARCH_INDEX_PROVIDER "io/mesalabs/unica/settings/ui/UISettingsFragment" "$SEARCH_PROVIDER_PATH"

DECODE_APK "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
_ADD_TOP_LEVEL_KEY()
{
    local KEY="$1"
    local SMALI_PATH="$2"
    local BEFORE
    local AFTER

    if grep -q -F "\"$KEY\"" "$SMALI_PATH"; then
        LOG "\033[0;33m! Top level key already present: $KEY\033[0m"
        return 0
    fi

    BEFORE="$(sha1sum "$SMALI_PATH")"
    perl -0pi -e 'my $done = 0; s{(\.method[^\n]*<init>\(Landroid/content/Context;\)V\s+\.locals )(\d+)}{if ($done) { $& } else { $done = 1; $1.($2 + 1) }}egs' "$SMALI_PATH"
    SETTINGS_TOP_LEVEL_KEY="$KEY" perl -0pi -e 'my $key = $ENV{"SETTINGS_TOP_LEVEL_KEY"}; my $done = 0; s{([ \t]*)filled-new-array/range \{v1 \.\. v(\d+)\}, \[Ljava/lang/String;\n\n[ \t]*move-result-object v1\n\n[ \t]*iput-object v1, v0, Lcom/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector;->SETTINGS_TOP_LEVEL_KEYS:\[Ljava/lang/String;}{if ($done) { $& } else { $done = 1; $1."const-string v".($2 + 1).", \"$key\"\n\n".$1."filled-new-array/range {v1 .. v".($2 + 1)."}, [Ljava/lang/String;\n\n".$1."move-result-object v1\n\n".$1."iput-object v1, v0, Lcom/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector;->SETTINGS_TOP_LEVEL_KEYS:[Ljava/lang/String;" }}egs' "$SMALI_PATH"
    AFTER="$(sha1sum "$SMALI_PATH")"

    if [[ "$BEFORE" == "$AFTER" ]] || ! grep -q -F "\"$KEY\"" "$SMALI_PATH"; then
        ABORT "Failed to add Settings Intelligence top level key: $KEY"
    fi
}

SETTINGS_INTELLIGENCE_APK_DIR="$APKTOOL_DIR/system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk"
TOP_LEVEL_KEYS_COLLECTOR_PATH="$(find "$SETTINGS_INTELLIGENCE_APK_DIR" -type f -path "*/com/samsung/android/settings/intelligence/search/categorizing/TopLevelKeysCollector.smali" | sort | head -n 1)"

if [ ! "$TOP_LEVEL_KEYS_COLLECTOR_PATH" ]; then
    ABORT "TopLevelKeysCollector.smali not found in SecSettingsIntelligence"
fi

LOG "- Patching \"${TOP_LEVEL_KEYS_COLLECTOR_PATH#$SETTINGS_INTELLIGENCE_APK_DIR/}\" in /system/system/priv-app/SecSettingsIntelligence.apk"
_ADD_TOP_LEVEL_KEY "top_level_unica" "$TOP_LEVEL_KEYS_COLLECTOR_PATH"

# Show Vulkan renderer toggle if required
if [[ "$(GET_PROP "ro.hwui.use_vulkan")" != "true" ]]; then
    SET_PROP "system" "persist.sys.unica.vulkan" "false"
fi

unset PATCH_INST CONTENT SECSETTINGS_APK_DIR SETTINGS_GATEWAY_PATH SETTINGS_ACTIVITY_PATH \
    FRAMEWORK_JAR_DIR ASKS_MANAGER_PATH \
    UNICA_SELINUX_DIR UNICA_PROPERTY_CONTEXTS \
    SOFTWARE_UPDATE_UTILS_PATH SOFTWARE_UPDATE_UTILS_SMALI \
    ONEUI_VERSION_CONTROLLER_PATH ONEUI_VERSION_CONTROLLER_SMALI \
    MODEL_NAME_GETTER_PATH MODEL_NAME_GETTER_SMALI \
    ADDED_SETTINGS_FRAGMENTS SETTINGS_FRAGMENT SETTINGS_FRAGMENT_COUNT \
    SEARCH_PROVIDER_PATH SETTINGS_SEARCH_BLOCK \
    SETTINGS_INTELLIGENCE_APK_DIR TOP_LEVEL_KEYS_COLLECTOR_PATH SETTINGS_TOP_LEVEL_KEY
unset -f _ADD_VALID_SETTINGS_FRAGMENT _BUMP_VALID_SETTINGS_LIMIT _ADD_SEARCH_INDEX_PROVIDER _ADD_TOP_LEVEL_KEY

LOG_STEP_OUT
