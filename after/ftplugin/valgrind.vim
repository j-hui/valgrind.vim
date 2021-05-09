if has('folding') && g:valgrind_enable_folding
    setl foldenable
    setl foldmethod=expr
    " If line is '==[[:PID:]]== ' and the following line is not, this line ends fold 1;
    " Else, if line begins with '==[[:PID:]]== ', this line is part of fold 1 (possibly starting it);
    " Else, this line is fold 0.
    setl foldexpr=getline(v:lnum)=~'^==\\d*==\\s$'&&getline(v:lnum+1)!~'^==\\d*==\\s$'?'<1':getline(v:lnum)=~'^==\\d*==\\s'?1:0
endif
