KERNEL_TMP_DIR="$TMP_DIR/proton_kernel"

EVAL "rm -rf \"$KERNEL_TMP_DIR\"" || return 1
EVAL "mkdir -p \"$KERNEL_TMP_DIR/stock\" \"$KERNEL_TMP_DIR/proton\"" || return 1

VENDOR_BOOT_INFO="$(unpack_bootimg --boot_img "$WORK_DIR/kernel/vendor_boot.img" --out "$KERNEL_TMP_DIR/stock" 2>&1)" || return 1
VENDOR_BOOT_PAGE_SIZE="$(sed -n "s/^page size: //p" <<< "$VENDOR_BOOT_INFO")"
VENDOR_BOOT_KERNEL_OFFSET="$(sed -n "s/^kernel load address: //p" <<< "$VENDOR_BOOT_INFO")"
VENDOR_BOOT_RAMDISK_OFFSET="$(sed -n "s/^ramdisk load address: //p" <<< "$VENDOR_BOOT_INFO")"
VENDOR_BOOT_TAGS_OFFSET="$(sed -n "s/^kernel tags load address: //p" <<< "$VENDOR_BOOT_INFO")"
VENDOR_BOOT_DTB_OFFSET="$(sed -n "s/^dtb address: //p" <<< "$VENDOR_BOOT_INFO")"
VENDOR_BOOT_CMDLINE="$(sed -n "s/^vendor command line args: //p" <<< "$VENDOR_BOOT_INFO")"
VENDOR_BOOT_BOARD="$(sed -n "s/^product name: //p" <<< "$VENDOR_BOOT_INFO")"

EVAL "cp -fa \"$SRC_DIR/platform/exynos2100/patches/bpf/proton/img/boot.img\" \"$WORK_DIR/kernel/boot.img\"" || return 1
EVAL "cp -fa \"$SRC_DIR/platform/exynos2100/patches/bpf/proton/img/vendor_boot.img\" \"$WORK_DIR/kernel/vendor_boot.img\"" || return 1

EVAL "unpack_bootimg --boot_img \"$WORK_DIR/kernel/vendor_boot.img\" --out \"$KERNEL_TMP_DIR/proton\"" || return 1
EVAL "mkbootimg \
    --header_version 3 \
    --pagesize \"$VENDOR_BOOT_PAGE_SIZE\" \
    --base 0x00000000 \
    --kernel_offset \"$VENDOR_BOOT_KERNEL_OFFSET\" \
    --ramdisk_offset \"$VENDOR_BOOT_RAMDISK_OFFSET\" \
    --tags_offset \"$VENDOR_BOOT_TAGS_OFFSET\" \
    --dtb_offset \"$VENDOR_BOOT_DTB_OFFSET\" \
    --vendor_cmdline \"$VENDOR_BOOT_CMDLINE\" \
    --board \"$VENDOR_BOOT_BOARD\" \
    --dtb \"$KERNEL_TMP_DIR/proton/dtb\" \
    --vendor_ramdisk \"$KERNEL_TMP_DIR/proton/vendor_ramdisk\" \
    --vendor_boot \"$WORK_DIR/kernel/vendor_boot.img\"" || return 1

EVAL "rm -rf \"$KERNEL_TMP_DIR\"" || return 1

unset KERNEL_TMP_DIR VENDOR_BOOT_INFO VENDOR_BOOT_PAGE_SIZE
unset VENDOR_BOOT_KERNEL_OFFSET VENDOR_BOOT_RAMDISK_OFFSET
unset VENDOR_BOOT_TAGS_OFFSET VENDOR_BOOT_DTB_OFFSET
unset VENDOR_BOOT_CMDLINE VENDOR_BOOT_BOARD
