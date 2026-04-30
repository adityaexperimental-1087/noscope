if [[ $TARGET_OS_SINGLE_SYSTEM_IMAGE == "essi" ]]; then
    LOG_STEP_IN "- Exynos device detected. Adding custom up_param."
    cp -a "$SRC_DIR/unica/mods/bootlogo/up_param_1440p.bin" "$WORK_DIR/up_param.bin"
    LOG_STEP_OUT
else
    LOG "- Non-Exynos device detected. Skipping custom up_param."
fi
