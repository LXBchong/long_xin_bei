set COMMON_ROOT [file dirname [info script]]
add_files [glob $COMMON_ROOT/include/*.svh]
add_files $COMMON_ROOT/include/bus_decl
add_files $COMMON_ROOT/util/
add_files $COMMON_ROOT/ram/
add_files $COMMON_ROOT/unit/
add_files $COMMON_ROOT/mycpu/
add_files $COMMON_ROOT/cache/
add_files $COMMON_ROOT/external/
