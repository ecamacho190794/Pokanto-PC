# Shared CMake helpers for a languages/<id> variant.
get_filename_component(POKANTO_LANGUAGES_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
get_filename_component(POKANTO_REPO_ROOT "${POKANTO_LANGUAGES_DIR}/.." ABSOLUTE)

function(pokanto_configure_language)
    cmake_parse_arguments(POKANTO
        "FIXED_ROM;APPLY_ROM_PATCH;HOST_EXIT_SIGNAL;ENGLISH_MOCKS"
        "LANGUAGE_DIR"
        ""
        ${ARGN})
    if(NOT POKANTO_LANGUAGE_DIR)
        message(FATAL_ERROR "pokanto_configure_language requires LANGUAGE_DIR")
    endif()

    if(TARGET gbrt)
        target_include_directories(gbrt BEFORE PRIVATE "${POKANTO_LANGUAGE_DIR}")
        if(POKANTO_FIXED_ROM)
            target_compile_definitions(gbrt PRIVATE GBRECOMP_POKANTO_FIXED_ROM=1)
        endif()
        if(POKANTO_APPLY_ROM_PATCH)
            target_compile_definitions(gbrt PRIVATE GBRECOMP_APPLY_ROM_PATCH=1)
        endif()
        if(POKANTO_HOST_EXIT_SIGNAL)
            target_compile_definitions(gbrt PRIVATE GBRECOMP_HOST_EXIT_SIGNAL=1)
        endif()
    endif()

    if(POKANTO_ENGLISH_MOCKS AND DEFINED GBRECOMP_GAME_TARGET)
        target_sources(${GBRECOMP_GAME_TARGET} PRIVATE
            ${POKANTO_REPO_ROOT}/pokemon/mock_gen1.c
            ${POKANTO_REPO_ROOT}/pokemon/mock_gen2.c
            ${POKANTO_REPO_ROOT}/pokemon/mock_ir.c
            ${POKANTO_REPO_ROOT}/pokemon/mock_inject_file.c
            ${POKANTO_REPO_ROOT}/pokemon/mock_evolve_patch.c
            ${POKANTO_REPO_ROOT}/pokemon/mock_wild_5050.c
            ${POKANTO_REPO_ROOT}/pokemon_overlay.cpp
        )
        target_include_directories(${GBRECOMP_GAME_TARGET} PRIVATE
            ${POKANTO_REPO_ROOT}/include
        )
        message(STATUS "${GBRECOMP_GAME_TARGET}: Pokémon mocks + overlay wired via languages/")
    endif()
endfunction()
