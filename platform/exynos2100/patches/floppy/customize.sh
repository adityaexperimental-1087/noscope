FLOPPY_REPO="https://github.com/FlopKernel-Series/flop_exynos2100_kernel.git"
FLOPPY_BRANCH="floppy-main"
FLOPPY_BASE_DIR="${KERNEL_TMP_DIR:-$SRC_DIR/out/kernel}/floppy-$TARGET_PLATFORM"
FLOPPY_KERNEL_DIR="$FLOPPY_BASE_DIR/kernel"
FLOPPY_BUILD_ARGS="${FLOPPY_BUILD_ARGS:-k}"

RUN_LIVE()
{
    local DESC="$1"
    shift

    LOG "- $DESC"
    "$@"
    local STATUS=$?

    if [ "$STATUS" -ne 0 ]; then
        ABORT "$DESC failed with exit code $STATUS"
    fi
}

SAFE_PULL_CHANGES()
{
    local PARENT
    PARENT="$(pwd)"

    cd "$FLOPPY_KERNEL_DIR"

    EVAL "git remote set-url origin \"$FLOPPY_REPO\""
    RUN_LIVE "Fetching FloppyKernel source" git fetch --prune origin "$FLOPPY_BRANCH"

    if ! git rev-parse --verify -q "$FLOPPY_BRANCH" > /dev/null; then
        EVAL "git checkout -q -B \"$FLOPPY_BRANCH\" \"origin/$FLOPPY_BRANCH\""
    else
        EVAL "git checkout -q \"$FLOPPY_BRANCH\""
    fi

    local LOCAL
    local REMOTE
    local BASE
    LOCAL="$(git rev-parse HEAD)"
    REMOTE="$(git rev-parse "origin/$FLOPPY_BRANCH")"
    BASE="$(git merge-base HEAD "origin/$FLOPPY_BRANCH")"

    if [[ "$LOCAL" == "$REMOTE" ]]; then
        LOG "- FloppyKernel source is up-to-date"
    elif [[ "$LOCAL" == "$BASE" ]]; then
        RUN_LIVE "Updating FloppyKernel source" git merge --ff-only "origin/$FLOPPY_BRANCH"
    elif [[ "$REMOTE" == "$BASE" ]]; then
        LOGW "- FloppyKernel source is ahead of remote; keeping local checkout"
    else
        cd "$PARENT"
        ABORT "FloppyKernel source history diverged. Please clean $FLOPPY_KERNEL_DIR and rebuild."
    fi

    RUN_LIVE "Updating FloppyKernel submodules" git submodule update --init --recursive

    cd "$PARENT"
}

PREPARE_KERNEL_SOURCE()
{
    if [[ -d "$FLOPPY_KERNEL_DIR/.git" ]]; then
        LOG "- Existing FloppyKernel source found"
        SAFE_PULL_CHANGES
    else
        EVAL "rm -rf \"$FLOPPY_KERNEL_DIR\""
        EVAL "mkdir -p \"$FLOPPY_BASE_DIR\""
        RUN_LIVE "Cloning FloppyKernel source" git clone --branch "$FLOPPY_BRANCH" --single-branch --recurse-submodules "$FLOPPY_REPO" "$FLOPPY_KERNEL_DIR"
    fi
}

PATCH_KERNEL_DEPS_SCRIPT()
{
    local DEPS_SCRIPT="$FLOPPY_KERNEL_DIR/build/scripts/deps.sh"

    if [ ! -f "$DEPS_SCRIPT" ]; then
        ABORT "FloppyKernel deps script not found: ${DEPS_SCRIPT//$SRC_DIR\//}"
    fi

    python3 - "$DEPS_SCRIPT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = '''if [ -f /etc/doas.conf ] && command -v "doas" &>/dev/null; then
\t  ROOT="doas"
elif command -v "sudo" &>/dev/null; then
\t  ROOT="sudo"
else
\t  log_err "neither doas nor sudo found."
\t  return 1
fi
'''
new = '''ROOT="${ROOT:-}"
'''
if old in text:
    text = text.replace(old, new, 1)

text = text.replace(
    'DEPS=( lz4 brotli flex bc cpio kmod zip binutils-aarch64-linux-gnu ccache )',
    'DEPS=( lz4 brotli flex bison bc cpio kmod zip aarch64-linux-gnu-ld ccache )',
)
text = text.replace(
    'local DEPS=( lz4 brotli flex bc cpio kmod zip ccache binutils-aarch64-linux-gnu )',
    'local DEPS=( lz4 brotli flex bison bc cpio kmod zip ccache aarch64-linux-gnu-ld )',
)
text = text.replace(
    'local DEPS=( lz4 brotli flex bc cpio kmod zip aarch64-linux-gnu-binutils ccache )',
    'local DEPS=( lz4 brotli flex bison bc cpio kmod zip aarch64-linux-gnu-ld ccache )',
)
text = text.replace(
    'local DEPS=( lz4 brotli flex bc cpio kmod ccache zip )',
    'local DEPS=( lz4 brotli flex bison bc cpio kmod ccache zip )',
)
text = text.replace(
    'local PKGS=( app-arch/lz4 app-arch/brotli sys-devel/flex sys-devel/bc app-arch/cpio sys-apps/kmod dev-util/ccache app-arch/zip )',
    'local PKGS=( app-arch/lz4 app-arch/brotli sys-devel/flex sys-devel/bison sys-devel/bc app-arch/cpio sys-apps/kmod dev-util/ccache app-arch/zip )',
)

old = '''    if [ ${#MISSING[@]} -gt 0 ]; then
        $ROOT apt-get update -qq || true
        $ROOT apt-get install -y "${MISSING[@]}"
    fi
'''
new = '''    if [ ${#MISSING[@]} -gt 0 ]; then
        log_err "Missing build dependencies: ${MISSING[*]}"
        log_info "Install them before building, then rerun the ROM build."
        exit 1
    fi
'''
text = text.replace(old, new, 1)

old = '''    if [ -n "$MISSING" ]; then
\t\t    $ROOT pacman -Syyuu --needed --noconfirm $MISSING
\t  fi
'''
new = '''    if [ -n "$MISSING" ]; then
        log_err "Missing build dependencies: $MISSING"
        log_info "Install them before building, then rerun the ROM build."
        exit 1
    fi
'''
text = text.replace(old, new, 1)

old = '''    if [ ${#MISSING[@]} -gt 0 ]; then
        $ROOT emerge -nvq "${MISSING[@]}"
    fi
'''
new = '''    if [ ${#MISSING[@]} -gt 0 ]; then
        log_err "Missing build dependencies: ${MISSING[*]}"
        log_info "Install them before building, then rerun the ROM build."
        exit 1
    fi
'''
text = text.replace(old, new, 1)

path.write_text(text)
PY
}

PATCH_KERNEL_NPU_ACCESS()
{
    local VISION_DEV="$FLOPPY_KERNEL_DIR/drivers/vision/vision-core/vision-dev.c"
    local DSP_CORE="$FLOPPY_KERNEL_DIR/drivers/vision/dsp/dsp-core.c"

    if [ ! -f "$VISION_DEV" ]; then
        ABORT "FloppyKernel vision device source not found: ${VISION_DEV//$SRC_DIR\//}"
    fi
    if [ ! -f "$DSP_CORE" ]; then
        ABORT "FloppyKernel DSP core source not found: ${DSP_CORE//$SRC_DIR\//}"
    fi

    python3 - "$VISION_DEV" "$DSP_CORE" <<'PY'
from pathlib import Path
import sys

vision_dev = Path(sys.argv[1])
dsp_core = Path(sys.argv[2])

text = vision_dev.read_text()
old = '''struct class vision_class = {
\t.name = VISION_NAME,
\t.dev_groups = vision_device_groups,
};
'''
new = '''static char *vision_devnode(struct device *dev, umode_t *mode)
{
\tif (dev && mode)
\t\t*mode = 0666;

\treturn NULL;
}

struct class vision_class = {
\t.name = VISION_NAME,
\t.dev_groups = vision_device_groups,
\t.devnode = vision_devnode,
};
'''

if new not in text:
    if old not in text:
        raise SystemExit("vision_class block not found")
    text = text.replace(old, new, 1)

vision_dev.write_text(text)

text = dsp_core.read_text()
old = '''\tdsp_miscdev->miscdev.fops = &dsp_file_ops;
\tdsp_miscdev->miscdev.parent = dspdev->dev;
'''
new = '''\tdsp_miscdev->miscdev.fops = &dsp_file_ops;
\tdsp_miscdev->miscdev.parent = dspdev->dev;
\tdsp_miscdev->miscdev.mode = 0666;
'''

if new not in text:
    if old not in text:
        raise SystemExit("DSP miscdevice block not found")
    text = text.replace(old, new, 1)

dsp_core.write_text(text)
PY
}

PATCH_KERNEL_HEX()
{
    local FILE="$1"
    local FROM="$2"
    local TO="$3"

    if xxd -p -c 0 "$FILE" | grep -q "$FROM"; then
        LOG "- Patching \"$FROM\" to \"$TO\" in ${FILE//$FLOPPY_KERNEL_DIR\//}"
        xxd -p -c 0 "$FILE" | sed "s/$FROM/$TO/" | xxd -r -p > "$FILE.tmp"
        mv -f "$FILE.tmp" "$FILE"
    fi
}

PATCH_KERNEL_FEATURE_DEFAULTS()
{
    local IMAGE="$1"
    local RELEASE
    local SDK

    RELEASE="$(GET_PROP "system" "ro.build.version.release")"
    SDK="$(GET_PROP "system" "ro.build.version.sdk")"

    if [[ "$RELEASE" =~ ^(1[6-9]|[2-9][0-9])(\..*)?$ ]] || [[ "$SDK" =~ ^(3[6-9]|[4-9][0-9])$ ]]; then
        LOG "- Enabling FloppyKernel uname BPF spoof default for Android 16+"
        PATCH_KERNEL_HEX "$IMAGE" "756e616d655f6270665f73706f6f663d30" "756e616d655f6270665f73706f6f663d32"
        PATCH_KERNEL_HEX "$IMAGE" "756e616d655f6270665f73706f6f663d31" "756e616d655f6270665f73706f6f663d32"
    fi
}

BUILD_KERNEL()
{
    local PARENT
    local STATUS
    PARENT="$(pwd)"

    cd "$FLOPPY_KERNEL_DIR"

    LOG "- Running FloppyKernel build script"
    set +e
    DO_ZIP=0 \
    DO_TAR=0 \
    USE_CCACHE="${FLOPPY_USE_CCACHE:-1}" \
    DEVICE="$TARGET_NAME" \
    CODENAME="$TARGET_CODENAME" \
    bash ./build/ckbuild.sh $FLOPPY_BUILD_ARGS
    STATUS=$?
    set -e

    if [ "$STATUS" -ne 0 ] && [[ "$FLOPPY_BUILD_ARGS" != *c* ]]; then
        LOGW "- FloppyKernel incremental build failed; retrying clean build"
        set +e
        DO_ZIP=0 \
        DO_TAR=0 \
        USE_CCACHE="${FLOPPY_USE_CCACHE:-1}" \
        DEVICE="$TARGET_NAME" \
        CODENAME="$TARGET_CODENAME" \
        bash ./build/ckbuild.sh c $FLOPPY_BUILD_ARGS
        STATUS=$?
        set -e
    fi

    if [ "$STATUS" -ne 0 ]; then
        cd "$PARENT"
        ABORT "FloppyKernel build failed with exit code $STATUS"
    fi

    cd "$PARENT"
}

REPACK_BOOT_IMAGE()
{
    local IMAGE="$1"

    if [ ! -f "$WORK_DIR/kernel/boot.img" ]; then
        ABORT "File not found: ${WORK_DIR//$SRC_DIR\//}/kernel/boot.img"
    fi

    if [ -d "$TMP_DIR" ]; then
        EVAL "rm -rf \"$TMP_DIR\""
    fi
    EVAL "mkdir -p \"$TMP_DIR\""
    EVAL "cp -a \"$WORK_DIR/kernel/boot.img\" \"$TMP_DIR/boot.img\""

    local MKBOOTIMG_ARGS
    MKBOOTIMG_ARGS="$(unpack_bootimg --boot_img "$TMP_DIR/boot.img" --out "$TMP_DIR/out" --format mkbootimg 2>&1)"

    if [ ! -f "$TMP_DIR/out/kernel" ]; then
        ABORT "Failed to extract boot.img\n\n$MKBOOTIMG_ARGS"
    fi

    EVAL "cp -a \"$IMAGE\" \"$TMP_DIR/out/kernel\""
    LOG "- Repacking boot.img with FloppyKernel Image"
    EVAL "mkbootimg $MKBOOTIMG_ARGS -o \"$TMP_DIR/new-boot.img\""
    echo -n "SEANDROIDENFORCE" >> "$TMP_DIR/new-boot.img"
    EVAL "mv -f \"$TMP_DIR/new-boot.img\" \"$WORK_DIR/kernel/boot.img\""
    EVAL "rm -rf \"$TMP_DIR\""
}

REPLACE_KERNEL_BINARIES()
{
    local IMAGE="$FLOPPY_KERNEL_DIR/out/arch/arm64/boot/Image"
    local VENDOR_BOOT="$FLOPPY_KERNEL_DIR/build/images/vendor_boot.img"

    PREPARE_KERNEL_SOURCE
    PATCH_KERNEL_DEPS_SCRIPT
    PATCH_KERNEL_NPU_ACCESS
    BUILD_KERNEL

    if [ ! -f "$IMAGE" ]; then
        ABORT "FloppyKernel Image not found: ${IMAGE//$SRC_DIR\//}"
    fi
    if [ ! -f "$VENDOR_BOOT" ]; then
        ABORT "FloppyKernel vendor_boot.img not found: ${VENDOR_BOOT//$SRC_DIR\//}"
    fi

    EVAL "cp -a \"$IMAGE\" \"$TMP_DIR-floppy-Image\""
    PATCH_KERNEL_FEATURE_DEFAULTS "$TMP_DIR-floppy-Image"
    REPACK_BOOT_IMAGE "$TMP_DIR-floppy-Image"
    EVAL "rm -f \"$TMP_DIR-floppy-Image\""

    LOG "- Replacing vendor_boot.img"
    EVAL "cp -a \"$VENDOR_BOOT\" \"$WORK_DIR/kernel/vendor_boot.img\""

    if [ -f "$FLOPPY_KERNEL_DIR/build/images/dtbo.img" ]; then
        LOG "- Replacing dtbo.img"
        EVAL "cp -a \"$FLOPPY_KERNEL_DIR/build/images/dtbo.img\" \"$WORK_DIR/kernel/dtbo.img\""
    else
        LOGW "- FloppyKernel build did not output dtbo.img; keeping target dtbo.img"
    fi
}

LOG_STEP_IN "- Building latest FloppyKernel"
REPLACE_KERNEL_BINARIES
LOG_STEP_OUT

unset FLOPPY_REPO FLOPPY_BRANCH FLOPPY_BASE_DIR FLOPPY_KERNEL_DIR FLOPPY_BUILD_ARGS
unset -f RUN_LIVE SAFE_PULL_CHANGES PREPARE_KERNEL_SOURCE PATCH_KERNEL_DEPS_SCRIPT PATCH_KERNEL_NPU_ACCESS PATCH_KERNEL_HEX PATCH_KERNEL_FEATURE_DEFAULTS BUILD_KERNEL REPACK_BOOT_IMAGE REPLACE_KERNEL_BINARIES
