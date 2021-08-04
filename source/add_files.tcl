set COMMON_ROOT [file dirname [info script]]
add_files [glob $COMMON_ROOT/include/*.svh]
add_files $COMMON_ROOT/include/bus_decl

add_files [glob $COMMON_ROOT/include/*.svh]
add_files [glob $COMMON_ROOT/util/*.sv]
# add_files [glob $COMMON_ROOT/ram/*.sv]
add_files [glob $COMMON_ROOT/unit/*.sv]
add_files [glob $COMMON_ROOT/mycpu/*.sv]
# add_files [glob $COMMON_ROOT/cache/*.sv]
add_files [glob $COMMON_ROOT/external/*.sv]

add_files $COMMON_ROOT/cache/DCache.sv
add_files $COMMON_ROOT/cache/ICache.sv
add_files $COMMON_ROOT/cache/ICache_se.sv
add_files $COMMON_ROOT/cache/LoadStoreBuffer.sv
add_files $COMMON_ROOT/cache/MMU.sv
add_files $COMMON_ROOT/cache/TU.sv

add_files $COMMON_ROOT/ram/D_BRAM_v2.sv
add_files $COMMON_ROOT/ram/D_LUTRAM_v2.sv
add_files $COMMON_ROOT/ram/I_BRAM.sv
add_files $COMMON_ROOT/ram/I_LUTRAM.sv
