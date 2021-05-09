if exists("loaded_valgrind")
    finish
endif
let loaded_valgrind = 1

if !exists(":Valgrind")
    command -nargs=* Valgrind call valgrind#Valgrind(<f-args>)
endif
" vim600:foldmethod=marker
