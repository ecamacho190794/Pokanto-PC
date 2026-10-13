# Spanish-only launcher behavior. The English build keeps its existing
# ROM-selection flow until the same change is intentionally ported there.
if(TARGET gbrt)
    target_compile_definitions(gbrt PRIVATE GBRECOMP_POKEMON_ES=1)
endif()
