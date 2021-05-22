if exists("loaded_valgrind")
    finish
endif
let loaded_valgrind = 1

if !exists(":Valgrind")
    command -bang -nargs=* Valgrind call valgrind#Cmd(<bang>0, <f-args>)
endif
" vim600:foldmethod=marker
