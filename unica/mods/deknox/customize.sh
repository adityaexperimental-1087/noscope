SET_PROP_IF_DIFF "vendor" "ro.security.fips.ux" "Disabled"

if [[ "$TARGET_OS_SINGLE_SYSTEM_IMAGE" != "qssi" ]] && \
        [[ "$TARGET_OS_SINGLE_SYSTEM_IMAGE" != "essi" ]] && \
        [[ "$TARGET_OS_SINGLE_SYSTEM_IMAGE" != "mssi" ]]; then
    ABORT "Unknown SSI: $TARGET_OS_SINGLE_SYSTEM_IMAGE"
fi

DELETE_FROM_WORK_DIR "system" "system/app/BlockchainBasicKit"
LOG_STEP_IN "- Keeping source Knox native stack"
LOG "- Keeping source vold, vdc, installd, apexd, gsid and Knox native libraries to avoid cross-SDK boot loops"
LOG_STEP_OUT
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.hdmapp.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.kgclient.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.kfbp.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.knnr.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.mpos.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.pushmanager.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.sandbox.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/privapp-permissions-com.samsung.android.knox.zt.framework.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/permissions/signature-permissions-com.samsung.android.kgclient.xml"
DELETE_FROM_WORK_DIR "system" "system/etc/sysconfig/preinstalled-packages-com.samsung.android.coldwalletservice.xml"
DELETE_FROM_WORK_DIR "system" "system/priv-app/HdmApk"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxFrameBufferProvider"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxGuard"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxMposAgent"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxNeuralNetworkRuntime"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxPushManager"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxSandbox"
DELETE_FROM_WORK_DIR "system" "system/priv-app/KnoxZtFramework"

LOG_STEP_IN "- Removing references to deleted Knox packages"
KNOX_REMOVED_PACKAGES=(
    "com.samsung.android.hdmapp"
    "com.samsung.android.kgclient"
    "com.samsung.android.knox.kfbp"
    "com.samsung.android.knox.knnr"
    "com.samsung.android.knox.mpos"
    "com.samsung.android.knox.pushmanager"
    "com.samsung.android.knox.sandbox"
    "com.samsung.android.knox.zt.framework"
)
KNOX_PACKAGE_CONFIGS=(
    "$WORK_DIR/system/system/etc/broadcast_allowlist.xml"
    "$WORK_DIR/system/system/etc/deviceidle/reviewed_allowlist.xml"
    "$WORK_DIR/system/system/etc/permissions/platform.xml"
    "$WORK_DIR/system/system/etc/sysconfig/allowed-system-preload-apps.xml"
    "$WORK_DIR/system/system/etc/sysconfig/required-packages.xml"
    "$WORK_DIR/system/system/etc/sysconfig/safe-mode-allow-list.xml"
)
for PACKAGE in "${KNOX_REMOVED_PACKAGES[@]}"; do
    PACKAGE_PATTERN="${PACKAGE//./\\.}"
    for FILE in "${KNOX_PACKAGE_CONFIGS[@]}"; do
        [ -f "$FILE" ] || continue
        EVAL "sed -i \"/package=\\\"$PACKAGE_PATTERN\\\"/d\" \"$FILE\""
    done
done
unset FILE KNOX_PACKAGE_CONFIGS KNOX_REMOVED_PACKAGES PACKAGE PACKAGE_PATTERN
LOG_STEP_OUT

if [[ "$TARGET_OS_SINGLE_SYSTEM_IMAGE" == "mssi" ]] || [[ "$TARGET_OS_SINGLE_SYSTEM_IMAGE" == "qssi" ]]; then
    APPLY_PATCH "system" "system/framework/framework.jar" \
        "$MODPATH/vold/framework.jar/0001-Add-token-argument-in-unlockCeStorage.patch"
    APPLY_PATCH "system" "system/framework/services.jar" \
        "$MODPATH/vold/services.jar/0001-Add-token-argument-in-unlockCeStorage.patch"
fi

DECODE_APK "system" "system/framework/services.jar"
SOURCE_FILE_ATTR="$(grep -F ".source" "$APKTOOL_DIR/system/framework/services.jar/smali/android/gsi/GsiProgress.smali")"
SOURCE_FILE_ATTR="${SOURCE_FILE_ATTR//\./\\\.}"
SOURCE_FILE_ATTR="${SOURCE_FILE_ATTR//\"/\\\"}"
SOURCE_FILE_ATTR="${SOURCE_FILE_ATTR//\//\\\/}"
LOG "- Replacing SourceFile attribute in /system/system/framework/services.jar"
find "$APKTOOL_DIR/system/framework/services.jar" -type f -name "*.smali" -print0 \
    | xargs -0 -I "{}" -P "$(nproc)" sed -i "s/^\.source.*/\.source \"SourceFile\"/g" "{}"
if [[ "$SOURCE_PRODUCT_SHIPPING_API_LEVEL" != "$TARGET_PRODUCT_SHIPPING_API_LEVEL" ]]; then
    SMALI_PATCH "system" "system/framework/services.jar" \
        "smali/com/android/server/knox/dar/ddar/ta/TAProxy.smali" "replace" \
        "updateServiceHolder(Z)V" \
        "$TARGET_PRODUCT_SHIPPING_API_LEVEL" \
        "$SOURCE_PRODUCT_SHIPPING_API_LEVEL" \
        > /dev/null
fi

# SEC_PRODUCT_FEATURE_KNOX_SUPPORT_DUAL_DAR
APPLY_PATCH "system" "system/app/Traceur/Traceur.apk" \
    "$MODPATH/ddar/Traceur.apk/0001-Nuke-Knox-DualDAR.patch"
APPLY_PATCH "system" "system/framework/framework.jar" \
    "$MODPATH/ddar/framework.jar/0001-Nuke-Knox-DualDAR.patch"
APPLY_PATCH "system" "system/framework/knoxsdk.jar" \
    "$MODPATH/ddar/knoxsdk.jar/0001-Nuke-Knox-DualDAR.patch"
APPLY_PATCH "system" "system/framework/services.jar" \
    "$MODPATH/ddar/services.jar/0001-Nuke-Knox-DualDAR.patch"
APPLY_PATCH "system" "system/priv-app/DeviceDiagnostics/DeviceDiagnostics.apk" \
    "$MODPATH/ddar/DeviceDiagnostics.apk/0001-Nuke-Knox-DualDAR.patch"
APPLY_PATCH "system" "system/priv-app/KnoxCore/KnoxCore.apk" \
    "$MODPATH/ddar/KnoxCore.apk/0001-Nuke-Knox-DualDAR.patch"
APPLY_PATCH "system" "system/priv-app/ManagedProvisioning/ManagedProvisioning.apk" \
    "$MODPATH/ddar/ManagedProvisioning.apk/0001-Nuke-Knox-DualDAR.patch"
APPLY_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "$MODPATH/ddar/SecSettingsIntelligence.apk/0001-Nuke-Knox-DualDAR.patch"
APPLY_PATCH "system_ext" "priv-app/StorageManager/StorageManager.apk" \
    "$MODPATH/ddar/StorageManager.apk/0001-Nuke-Knox-DualDAR.patch"

# SEC_PRODUCT_FEATURE_KNOX_SUPPORT_HDM
APPLY_PATCH "system" "system/app/Traceur/Traceur.apk" \
    "$MODPATH/hdm/Traceur.apk/0001-Nuke-Knox-HDM.patch"
APPLY_PATCH "system" "system/framework/knoxsdk.jar" \
    "$MODPATH/hdm/knoxsdk.jar/0001-Nuke-Knox-HDM.patch"
APPLY_PATCH "system" "system/framework/services.jar" \
    "$MODPATH/hdm/services.jar/0001-Nuke-Knox-HDM.patch"
APPLY_PATCH "system" "system/priv-app/DeviceDiagnostics/DeviceDiagnostics.apk" \
    "$MODPATH/hdm/DeviceDiagnostics.apk/0001-Nuke-Knox-HDM.patch"
APPLY_PATCH "system" "system/priv-app/ManagedProvisioning/ManagedProvisioning.apk" \
    "$MODPATH/hdm/ManagedProvisioning.apk/0001-Nuke-Knox-HDM.patch"
APPLY_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "$MODPATH/hdm/SecSettings.apk/0001-Nuke-Knox-HDM.patch"
APPLY_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "$MODPATH/hdm/SecSettingsIntelligence.apk/0001-Nuke-Knox-HDM.patch"
APPLY_PATCH "system_ext" "priv-app/StorageManager/StorageManager.apk" \
    "$MODPATH/hdm/StorageManager.apk/0001-Nuke-Knox-HDM.patch"

# SEC_PRODUCT_FEATURE_KNOX_SUPPORT_BLDP
SMALI_PATCH "system" "system/app/Traceur/Traceur.apk" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isBldpEventSupported()Z' 'false'
SMALI_PATCH "system" "system/framework/knoxsdk.jar" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isBldpEventSupported()Z' 'false'
SMALI_PATCH "system" "system/priv-app/DeviceDiagnostics/DeviceDiagnostics.apk" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isBldpEventSupported()Z' 'false'
SMALI_PATCH "system" "system/priv-app/ManagedProvisioning/ManagedProvisioning.apk" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isBldpEventSupported()Z' 'false'
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes4/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isBldpEventSupported()Z' 'false'
SMALI_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "smali_classes2/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isBldpEventSupported()Z' 'false'
SMALI_PATCH "system_ext" "priv-app/StorageManager/StorageManager.apk" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isBldpEventSupported()Z' 'false'
SMALI_PATCH "system_ext" "priv-app/SystemUI/SystemUI.apk" \
    "smali_classes4/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isBldpEventSupported()Z' 'false'

# SEC_PRODUCT_FEATURE_KNOX_SUPPORT_MPOS
# TODO add services.jar patch
SMALI_PATCH "system" "system/app/Traceur/Traceur.apk" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isMposSupported()Z' 'false'
SMALI_PATCH "system" "system/framework/knoxsdk.jar" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isMposSupported()Z' 'false'
SMALI_PATCH "system" "system/priv-app/DeviceDiagnostics/DeviceDiagnostics.apk" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isMposSupported()Z' 'false'
SMALI_PATCH "system" "system/priv-app/ManagedProvisioning/ManagedProvisioning.apk" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isMposSupported()Z' 'false'
SMALI_PATCH "system" "system/priv-app/SecSettings/SecSettings.apk" \
    "smali_classes4/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isMposSupported()Z' 'false'
SMALI_PATCH "system" "system/priv-app/SecSettingsIntelligence/SecSettingsIntelligence.apk" \
    "smali_classes2/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isMposSupported()Z' 'false'
SMALI_PATCH "system_ext" "priv-app/StorageManager/StorageManager.apk" \
    "smali/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isMposSupported()Z' 'false'
SMALI_PATCH "system_ext" "priv-app/SystemUI/SystemUI.apk" \
    "smali_classes4/com/samsung/android/knox/integrity/EnhancedAttestationPolicy.smali" "return" \
    'isMposSupported()Z' 'false'

# SEC_PRODUCT_FEATURE_KNOX_SUPPORT_KNOXGUARD
APPLY_PATCH "system" "system/framework/services.jar" \
    "$MODPATH/knoxguard/services.jar/0001-Disable-KnoxGuard.patch"

# SEC_PRODUCT_FEATURE_SECURITY_SUPPORT_KNOX_MATRIX_AI_PRIVACY
APPLY_PATCH "system" "system/framework/framework.jar" \
    "$MODPATH/kmxai/framework.jar/0001-Nuke-Knox-Matrix-AI-Privacy.patch"

# SEC_PRODUCT_FEATURE_FRAMEWORK_SUPPORT_BLOCKCHAIN_SERVICE
SET_FLOATING_FEATURE_CONFIG "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_BLOCKCHAIN_SERVICE" --delete
SMALI_PATCH "system" "system/framework/framework.jar" \
    "smali_classes6/com/samsung/android/ProductPackagesRune.smali" "replaceall" \
    "SERVICE_SAMSUNG_BLOCKCHAIN:Z = true" \
    "SERVICE_SAMSUNG_BLOCKCHAIN:Z = false"
if [[ "$TARGET_SECURITY_CONFIG_ESE_CHIP_VENDOR" == "none" ]] && [[ "$TARGET_SECURITY_CONFIG_ESE_COS_NAME" == "none" ]]; then
    APPLY_PATCH "system" "system/framework/services.jar" \
        "$MODPATH/ese+blockchain/services.jar/0001-Nuke-BlockchainTZService.patch"
else
    APPLY_PATCH "system" "system/framework/services.jar" \
        "$MODPATH/blockchain/services.jar/0001-Nuke-BlockchainTZService.patch"
fi

# TODO get rid of the following features
# SEC_PRODUCT_FEATURE_KNOX_SUPPORT_UCS
# SEC_PRODUCT_FEATURE_FRAMEWORK_SUPPORT_MOBILE_PAYMENT

LOG "- Restoring original SourceFile attribute in /system/system/framework/services.jar"
find "$APKTOOL_DIR/system/framework/services.jar" -type f -name "*.smali" -print0 \
    | xargs -0 -I "{}" -P "$(nproc)" sed -i "s/^\.source.*/$SOURCE_FILE_ATTR/g" "{}"

unset SOURCE_FILE_ATTR
