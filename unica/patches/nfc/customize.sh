source "$SRC_DIR/scripts/utils/common_utils.sh"
source "$SRC_DIR/scripts/utils/module_utils.sh"

E3Q_NFC_BLOBS="
system/etc/libnfc-nci.conf
system/lib64/libnfc_nci_jni.so
system/lib64/libnfc_prop_extn.so
system/lib64/libnfc_vendor_extn.so
"

for NFC_BLOB in $E3Q_NFC_BLOBS; do
    NFC_LABEL="u:object_r:system_file:s0"
    [[ "$NFC_BLOB" == *.so ]] && NFC_LABEL="u:object_r:system_lib_file:s0"

    ADD_TO_WORK_DIR "e3qxxx" "system" "$NFC_BLOB" 0 0 644 "$NFC_LABEL"
done

DELETE_FROM_WORK_DIR "system" "system/etc/libnfc-nci_temp.conf"
DELETE_FROM_WORK_DIR "system" "system/lib/libnfc_sec_jni.so"
DELETE_FROM_WORK_DIR "system" "system/lib64/libnfc_sec_jni.so"

SET_PROP "vendor" "ro.vendor.nfc.info.antpos" "27"

DECODE_APK "system" "system/priv-app/SecSettings/SecSettings.apk"

# avoid crashed when open NFC settings
FTP="
system/priv-app/SecSettings/SecSettings.apk/smali_classes5/com/samsung/android/settings/nfc/NfcAntennaGuideDialog.smali
system/priv-app/SecSettings/SecSettings.apk/smali_classes5/com/samsung/android/settings/nfc/NfcSettings.smali
"
for f in $FTP; do
   sed -i "s/\"27\"/\"1\"/g" "$APKTOOL_DIR/$f"
done