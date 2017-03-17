" Vim global plugin for valgrind
" Initial author: Rainer M. Schmid <rms@trolltech.com>
" Maintainer: Luke Humphreys
" Contribution: Luc Hermitte 2017, CMake support
" Version: forked from v1.2


" General:
"
" Put this script in your .vim/plugin directory. It adds the command
" ":Valgrind" to run valgrind with the specified options. I usually start this
" with the following small script:
"
"    #!/bin/sh
"    vim -c "Valgrind $*" -c "only"
"
" Options:
"
" You can configure the behaviour with the following variables:
"
" g:valgrind_command
"    The command to start valgrind. If this variable is not set, "valgrind" is
"    used.
"
" g:valgrind_arguments
"    The arguments that should always be used when running valgrind. If this
"    variable is not set, "--num-callers=5000" is used.
"
" g:valgrind_use_horizontal_window
"    If this variable is set to a value not equal 0, the script uses
"    horizontal splits to show new windows. Otherwise it uses vertical splits.
"    The default is to use vertical splits.
"
" g:valgrind_win_width
"    Specifies the width of the window that shows the valgrind output. This
"    variable is only used with vertical splits. Defaults to 30.
"
" g:valgrind_win_height
"    Specifies the height of the window that shows the valgrind output. This
"    variable is only used with vertical splits. Defaults to 10.
"
" g:dont_export_hotkeys
"    Don't remap <C-k> and <C-j> to navigate the call stack
"
" g:valgrind_file_process_hook
"    Sometimes vagrind outputs are post-processed by other tools like CTest
"    that add leading characters like "42: ". Define this action to execute on
"    the current buffer to restore valgrind output. For CTest, it would be:
"       :let g:valgrind_file_process_hook = '%s/\v^\d\+: //'
"
" Example:
"
" If you want valgrind to always do leak checking, put the following into your
" .vimrc:
"
"     let g:valgrind_arguments='--leak-check=yes --num-callers=5000'

" Startup {{{

if exists("loaded_valgrind")
    finish
endif
let loaded_valgrind = 1

" save cpo (we use line-continuation)
let s:save_cpo = &cpo
set cpo&vim

" }}}

"--------------------------------------------
" Global mappings and commands
"--------------------------------------------
" Commands {{{

if !exists(":Valgrind")
    command -nargs=1 Valgrind call <SID>Valgrind(<f-args>)
    command  Memtest call <SID>Valgrind()
endif


" }}}
" Options {{{

if !exists('g:valgrind_win_width')
    let g:valgrind_win_width = 30
endif
if !exists('g:valgrind_win_height')
    let g:valgrind_win_height = 10
endif

" }}}

"--------------------------------------------
" Functions
"--------------------------------------------
" Valgrind( filename ) {{{

function! s:Valgrind( ... )
    let l:tmpfile=tempname()

    " construct the commandline and execute it
    let l:run_valgrind = '!'

    let l:run_valgrind .= get(g:, 'valgrind_command', 'valgrind')
    let l:run_valgrind .= ' '.get(g:, 'valgrind_arguments', '--num-callers=5000')

    "add any custom arguments
    let l:run_valgrind .= join(a:000, ' ')

    let l:run_valgrind .= ' 2>&1| tee '.l:tmpfile
    execute l:run_valgrind

    " show the result with the non-valgrind output stripped
    if  exists("s:val_buffer") && s:val_buffer == bufname(winbufnr(s:val_winnum))
        silent execute s:val_winnum.'wincmd w'
        silent execute 'edit ' . l:tmpfile
    else
        silent execute 'split '.l:tmpfile
    endif
    if exists('g:valgrind_file_process_hook')
      silent execute g:valgrind_file_process_hook
    endif
    silent execute 'g!/^==\d*==/d'
    silent execute '%s/^==\d*== //e'
    silent execute '1'

    " Keep the valgrind buffer for future use
    let s:val_buffer = bufname(l:tmpfile)
    let s:val_winnum = bufwinnr(s:val_buffer)

    " make the buffer non-editable
    setl buftype=nowrite
    setl nobuflisted
    setl bufhidden=hide
    setl nomodifiable
    setl nowrap

    " syntax highlighting
    if has('syntax')
        syntax match ValgrindComment '^" .*'

        highlight clear ValgrindComment
        highlight link ValgrindComment Comment
    endif

    " fold settings
    if has('folding')
        setl foldenable
        setl foldmethod=expr
        setl foldexpr=getline(v:lnum)=~'^\\s*$'&&getline(v:lnum+1)=~'\\S'?'<1':1
    endif


    " show help
    call <SID>Show_Help(1)

    " mappings to go to error
    nnoremap <buffer> <silent> <CR> :call <SID>Jump_To_Error(0,0)<CR>
    nnoremap <buffer> <silent> o :call <SID>Jump_To_Error(1,0)<CR>
    nnoremap <buffer> <silent> <2-LeftMouse> :call <SID>Jump_To_Error(0,0)<CR>
    nnoremap <buffer> <silent> <Space> :call <SID>Jump_To_Error(0,1)<CR>
    " mappings for fold handlin
    nnoremap <buffer> <silent> + :silent! foldopen<CR>
    nnoremap <buffer> <silent> - :silent! foldclose<CR>
    nnoremap <buffer> <silent> * :silent! %foldopen!<CR>
    nnoremap <buffer> <silent> <kPlus> :silent! foldopen<CR>
    nnoremap <buffer> <silent> <kMinus> :silent! foldclose<CR>
    nnoremap <buffer> <silent> <kMultiply> :silent! %foldopen!<CR>
    " misc. mappings
    nnoremap <buffer> <silent> x :call <SID>Zoom_Window()<CR>
    nnoremap <buffer> <silent> ? :call <SID>Show_Help(0)<CR>
    nnoremap <buffer> <silent> q :close<CR>

    " Navigate the call statck
    if !(exists("g:dont_export_hotkeys") && g:dont_export_hotkeys)
        nnoremap <silent> <C-k> :call <SID>Up()<CR>
        nnoremap <silent> <C-j> :call <SID>Down()<CR>
    endif
endfunction

" }}}
" Find_File( filename ) {{{

function! s:Find_File( filename )
    if filereadable( a:filename )
    return a:filename
    else
    " ### implement me
    "echo globpath( &path, a:filename )
    endif
endfunction

" }}}
" Jump_To_Error( new_window, stay_valgrind_window ) {{{

function! s:Jump_To_Error(new_window, stay_valgrind_window )
    " do not process empty lines
    let l:curline = getline('.')
    if l:curline == ''
        return
    endif

    " export the line number so we can navigate the call stack
    let s:lineNo = line(".")

    call s:OpenStackTraceLine(a:new_window, a:stay_valgrind_window, l:curline)


endfunction

function! s:OpenStackTraceLine(new_window, no_new_window, stackLine )
    " What does it mean to say "no new window?"
    let l:stay_this_window = a:no_new_window
    let l:stay_valgrind_window = 0
    if l:stay_this_window && winnr() == s:val_winnum
        let l:stay_valgrind_window = 1
        let l:stay_this_window = 0
    endif

    " if inside a fold, open it
    if foldclosed('.') != -1
        execute "foldopen"
        return -1
    endif

    " if the line doesn't start with "   at" or "   by" , return
    if match( a:stackLine, "   at" ) != 0 &&  match( a:stackLine, "   by" ) != 0
        return -1
    endif

    " determine file and line to go to
    let l:curline = substitute( substitute( a:stackLine, '.*(', '', '' ), ').*', '', '' )
    let l:filename = s:Find_File( substitute( l:curline, ':\d*$', '', '' ) )
    if l:filename == ""
        return 1
    endif
    let l:linenumber = substitute( l:curline, '.*:', '', '' )

    " Goto the window containing the file with name l:filename. If the window
    " is not there, open a new window
    if bufname( l:filename ) == ""
        let l:bufnum = -1
    else
        let l:bufnum = bufnr( bufname( l:filename ) )
    endif

    let l:winnum = bufwinnr( l:bufnum )
    if l:bufnum == -1 || l:winnum == -1
        "first find or create a suitable window
        if l:stay_this_window
            let l:this_win = winnr()
            execute l:this_win.'wincmd w'
        else
            if exists("g:valgrind_use_horizontal_window") && g:valgrind_use_horizontal_window
                " Move to the next window down
                wincmd j
                let l:winnum = winnr()
                if l:winnum == s:val_winnum
                    execute 'leftabove new'
                    let l:winnum = winnr()
                endif
            else
                wincmd l
                let l:winnum = winnr()
                if l:winnum == s:val_winnum
                    execute 'rightbelow vertical new'
                    let l:winnum = winnr()
                endif
            endif
        endif

        " open the file in that window
        if ( l:bufnum == -1 )
            silent! execute 'edit '.l:filename
        else
            silent! execute 'edit #'.l:bufnum
        endif

        if v:errmsg != ""
            echoerr v:errmsg
            execute s:val_winnum.'wincmd w'
            return 1
        endif

            execute s:val_winnum.'wincmd w'
        if exists("g:valgrind_use_horizontal_window") && g:valgrind_use_horizontal_window
            execute 'resize '.g:valgrind_win_height
        else
            execute 'vertical resize '.g:valgrind_win_width
        endif
            execute l:winnum.'wincmd w'
    else
        execute l:winnum.'wincmd w'
        if a:new_window
            split
        endif
    endif

    " Mark the error
    let l:marker = {'filename': l:filename, 'lnum': l:linenumber, 'type': 'E'}
    call setqflist([l:marker], 'a')

    " Goto the line l:linenumber and open a fold, if there is one.
    execute l:linenumber
    if foldclosed('.') != -1
        execute "foldopen"
    endif
    normal zz

    if ( l:stay_valgrind_window )
        execute s:val_winnum.'wincmd w'
    endif

    return 1

endfunction

function! s:Up()
    let s:lineNo = s:lineNo + 1
    let l:stackLine = getbufline(s:val_buffer,s:lineNo)
    if s:OpenStackTraceLine(0, 1, l:stackLine[0]) == -1
        "Don't increment the line if we didn't move the stack
        let s:lineNo = s:lineNo - 1
    endif
endfunction

function! s:Down()
    let s:lineNo = s:lineNo - 1
    let l:stackLine = getbufline(s:val_buffer,s:lineNo)
    if s:OpenStackTraceLine(0, 1, l:stackLine[0]) == -1
        "Don't increment the line if we didn't move the stack
        let s:lineNo = s:lineNo + 1
    endif
endfunction

" }}}
" Zoom_Window() {{{

function! s:Zoom_Window()
    if !exists("s:win_maximized")
    let s:win_maximized = 0
    endif
    if s:win_maximized
        if exists("g:valgrind_use_horizontal_window") && g:valgrind_use_horizontal_window
            execute 'resize ' . g:valgrind_win_height
        else
            execute 'vertical resize ' . g:valgrind_win_width
        endif
        let s:win_maximized = 0
    else
        if exists("g:valgrind_use_horizontal_window") && g:valgrind_use_horizontal_window
            resize
        else
            vertical resize
        endif
        let s:win_maximized = 1
    endif
endfunction

" }}}
" Show_Help( first_time ) {{{

function! s:Show_Help( first_time )
    setl modifiable

    if !a:first_time
    normal G$
    if ( search( '^$', 'w' ) > 0 )
        normal d1G
    endif
    endif

    if exists("s:show_help") && s:show_help == 1
    call append(0, '" <enter> : Jump to error')
    call append(1, '" o : Jump to error in new window')
    call append(2, '" <space> : Show error')
    call append(3, '" x : Zoom-out/Zoom-in valgrind window')
    call append(4, '" + : Open a fold')
    call append(5, '" - : Close a fold')
    call append(6, '" * : Open all folds')
    call append(7, '" q : Close the valgrind window')
    call append(8, '" ? : Remove help text')
    call append(9, '')
        let s:show_help = 0
    else
    call append(0, '" Press ? to display help text')
    call append(1, '')
        let s:show_help = 1
    endif

    normal 1G
    foldopen

    setl nomodifiable
endfunction

" }}}

" Cleanup {{{

" restore cpo
let &cpo = s:save_cpo

" }}}

" vim600:foldmethod=marker
