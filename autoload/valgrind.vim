" save cpo (for line-continuation)
let s:save_cpo = &cpo
set cpo&vim

"--------------------------------------------
" Options
"--------------------------------------------

if !exists('g:valgrind_command')
  let g:valgrind_command = 'valgrind'
endif

if !exists('g:valgrind_arguments')
  let g:valgrind_command = '--num-callers=5000'
endif

if !exists('g:valgrind_win_height')
    let g:valgrind_win_height = 24
endif

if !exists("g:valgrind_strip_program_output")
  let g:valgrind_strip_program_output = 1
endif

if !exists("g:valgrind_enable_folding")
  let g:valgrind_enable_folding = 1
endif

"--------------------------------------------
" Internal state
"--------------------------------------------

" Used by s:Up() and s:Down() to navigate the call stack from outside of the
" Valgrind buffer.
let s:stack_line_no = -1
let s:valgrind_buffer = ''

"--------------------------------------------
" Functions
"--------------------------------------------

function! valgrind#Valgrind(...)
    if len(a:000) == 0
        if s:valgrind_buffer != '' && bufwinnr(s:valgrind_buffer) != -1
            silent execute bufwinnr(s:valgrind_buffer) . 'wincmd w'
        elseif s:valgrind_buffer != ''
            silent execute 'split ' . s:valgrind_buffer
            silent execute 'resize ' . g:valgrind_win_height
        else
            echoerr 'No existing valgrind buffer. Please run :Valgrind with arguments first.'
        endif
        return
    endif

    let l:tmpfile = tempname()

    " Construct the commandline
    let l:run_valgrind = '!' . g:valgrind_command . ' ' . g:valgrind_arguments

    " Add any custom arguments
    let l:run_valgrind .= ' ' . join(a:000, ' ')
    let l:run_valgrind .= ' 2>&1| tee ' . l:tmpfile

    execute l:run_valgrind

    " Show the result of the valgrind output, trying to reuse the last
    " valgrind buffer if it is still visible in a window
    if s:valgrind_buffer != '' && bufwinnr(s:valgrind_buffer) != -1
        silent execute bufwinnr(s:valgrind_buffer) . 'wincmd w'
        silent execute 'edit ' . l:tmpfile
    else
        silent execute 'split ' . l:tmpfile
        silent execute 'resize ' . g:valgrind_win_height
    endif

    " Remember the valgrind buffer for future use
    let s:valgrind_buffer = bufname(l:tmpfile)

    " Reset stack line position
    let s:stack_line_no = -1

    if g:valgrind_strip_program_output
        silent execute 'g!/^==\d*==/d'
        " silent execute '%s/^==\d*== $//'
    endif

    if has('syntax')
        set filetype=valgrind
    endif

    doautocmd User ValgrindEnter

    " Make the buffer non-editable
    setl buftype=nowrite
    setl nobuflisted
    setl bufhidden=hide
    setl nomodifiable
    setl nowrap

    " Return to top
    silent execute '1'

    " Valgrind buffer-local mappings
    nnoremap <buffer> <silent> <CR>           :call <SID>Jump_To_Error(0)<CR>
    nnoremap <buffer> <silent> o              :call <SID>Jump_To_Error(1)<CR>
    nnoremap <buffer> <silent> q              :close<CR>
    nnoremap <buffer> <silent> ?              :help valgrind-buf-maps<CR>

    " Global mappings
    nnoremap <silent> <Plug>ValgrindStackUp   :call valgrind#ValgrindUp()<CR>
    nnoremap <silent> <Plug>ValgrindStackDown :call valgrind#ValgrindDown()<CR>
endfunction

function! s:Jump_To_Error(follow_focus)
    if foldclosed('.') != -1
        execute "foldopen"
        return -1
    endif

    let l:curline = getline('.')
    if l:curline !~# '^==\d*==\s\+\(by\|at\)'
        " No interesting Valgrind output to process here
        return
    endif

    " Export the line number so we can navigate the call stack
    let s:stack_line_no = line(".")

    call s:OpenStackTraceLine(a:follow_focus, l:curline)
endfunction

function! valgrind#ValgrindUp()
  call s:StackMove(1)
endfunction

function! valgrind#ValgrindDown()
  call s:StackMove(0)
endfunction

function! s:StackMove(up)
    if s:stack_line_no < 0
      return
    endif

    let l:old_line_no = s:stack_line_no

    if a:up
      let s:stack_line_no = s:stack_line_no + 1
    else
      let s:stack_line_no = s:stack_line_no - 1
    endif

    let l:stackline = getbufline(s:valgrind_buffer, s:stack_line_no)
    if len(l:stackline) < 1 || l:stackline[0] !~# '^==\d*==\s\+\(by\|at\)'
        " No interesting Valgrind output to process here.
        let s:stack_line_no = l:old_line_no
        return
    endif

    call s:OpenStackTraceLine(1, l:stackline[0])
endfunction

function! s:Find_File(filename)
    if filereadable(a:filename)
        return a:filename
    else
        " ### FIXME
        "echo globpath( &path, a:filename )
    endif
endfunction

function! s:OpenStackTraceLine(follow_focus, stackline)
    " Determine file and line to go to
    let l:curline = substitute(substitute(a:stackline, '.*(', '', ''), ').*', '', '')
    let l:filename = s:Find_File(substitute(l:curline, ':\d*$', '', '' ))
    if l:filename == ''
        return 1
    endif
    let l:linenumber = substitute(l:curline, '.*:', '', '')

    let l:created_new_window = 0
    let l:was_in_valgrind = 0
    if bufname() == s:valgrind_buffer
        " Currently in valgrind buffer; jump to previous window, which we will
        " use to show the stack trace line.
        let l:was_in_valgrind = 1
        let l:prev_win = winnr('#')
        if l:prev_win
            execute l:prev_win . 'wincmd w'
        else
            " Or if no such window exists, create it
            belowright new
            let l:created_new_window = 1
        endif
    endif

    silent! execute 'edit ' . l:filename
    if v:errmsg != ""
        echoerr v:errmsg
        if l:created_new_window
            close
        endif
        return 1
    endif

    " Goto the line l:linenumber and open a fold, if there is one.
    execute l:linenumber
    if foldclosed('.') != -1
        execute "foldopen"
    endif
    normal! zz

    if !a:follow_focus && l:was_in_valgrind
        execute bufwinnr(s:valgrind_buffer) . 'wincmd w'
    endif

    return 1
endfunction

let &cpo = s:save_cpo
