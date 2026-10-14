# The Spanish recompile uses the patched ROM image. Validate and apply its BPS
# before loading ROM-backed data, and consume the game's host-exit signal.
if(TARGET gbrt)
    target_include_directories(gbrt BEFORE PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../languages/es")
    target_compile_definitions(gbrt PRIVATE
        GBRECOMP_POKANTO_FIXED_ROM=1
        GBRECOMP_POKEMON_ES=1
        GBRECOMP_APPLY_ROM_PATCH=1
        GBRECOMP_HOST_EXIT_SIGNAL=1
    )
endif()
