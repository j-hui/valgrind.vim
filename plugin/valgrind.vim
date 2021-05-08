if exists("loaded_valgrind")
    finish
endif
let loaded_valgrind = 1

if !exists(":Valgrind")
    command -nargs=1 Valgrind call valgrind#Valgrind(<f-args>)
    command  Memtest call valgrind#Valgrind()
endif
" vim600:foldmethod=marker
