    BLOBS_LIST="
    system/etc/libnfc-nci.conf
    system/lib64/libnfc_nci_jni.so
    system/lib64/libnfc_prop_extn.so
    system/lib64/libnfc_vendor_extn.so
    "
    for blob in $BLOBS_LIST
    do
        ADD_TO_WORK_DIR "e3qxxx" "system" "$blob" 0 0 644 "u:object_r:system_lib_file:s0"
    done

