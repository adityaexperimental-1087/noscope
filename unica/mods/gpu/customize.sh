
source "$SRC_DIR/scripts/utils/common_utils.sh"
source "$SRC_DIR/scripts/utils/module_utils.sh"

LOG "- Applying r9s \"vulkan 1.3 & r38p1 Latest\"..."

# copy new blobs
ADD_TO_WORK_DIR "r9sxxx" "vendor" "etc/permissions/android.hardware.vulkan.compute.xml" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "r9sxxx" "vendor" "etc/permissions/android.software.vulkan.deqp.level.xml" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "r9sxxx" "vendor" "etc/permissions/android.hardware.vulkan.version.xml" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "r9sxxx" "vendor" "etc/permissions/android.hardware.vulkan.level.xml" 0 0 644 "u:object_r:vendor_configs_file:s0"

ADD_TO_WORK_DIR "r9sxxx" "vendor" "lib/egl/libGLES_mali.so" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "r9sxxx" "vendor" "lib/hw/vulkan.mali.so" 0 0 644 "u:object_r:vendor_configs_file:s0"

ADD_TO_WORK_DIR "r9sxxx" "vendor" "lib64/egl/libGLES_mali.so" 0 0 644 "u:object_r:vendor_configs_file:s0"
ADD_TO_WORK_DIR "r9sxxx" "vendor" "lib64/hw/vulkan.mali.so" 0 0 644 "u:object_r:vendor_configs_file:s0"
