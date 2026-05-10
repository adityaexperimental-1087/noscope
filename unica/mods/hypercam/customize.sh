source "$SRC_DIR/scripts/utils/common_utils.sh"
source "$SRC_DIR/scripts/utils/module_utils.sh"


LOG_STEP_IN "- Adding Hyper Camera"

ADD_TO_WORK_DIR "$SRC_DIR/unica/mods/hypercam" "system" "system/priv-app/hypercam" 0 0 644 "u:object_r:system_file:s0"


LOG_STEP_OUT