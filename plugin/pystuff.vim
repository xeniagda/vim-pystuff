
" Options:
let g:pystuff#pep_file_name = "Pep of "
let g:pystuff#outline_file_name = "Outline of "

let s:spath = expand("<sfile>:p:h")

function! pystuff#command_exists(command)
    silent exec "!hash " . a:command . " &2>/dev/null"
    return v:shell_error == 0
endf

function! pystuff#pep_update(python_buf, outline_buf)

    " Switch to the outline buffer
    
    exec "sp|" . a:outline_buf . "b!"
    setlocal modifiable modified noreadonly

    if !pystuff#command_exists("pep8")
        echoerr "pep8 is required. Install it by doing running  pip install pep8"
        return
    endif

    %d
    silent! exec ":r!pep8 " . bufname(a:python_buf)

    normal ggdd

    setlocal nomodifiable nomodified readonly
    q!
endf

function! pystuff#pep_setup(python_buf, outline_buf)
endfunction

function! pystuff#Pep()
     call pystuff#bind(function("pystuff#pep_setup"), function("pystuff#pep_update"), g:pystuff#pep_file_name, "pep")

endfunction

function! pystuff#outline_update(python_buf, outline_buf)
    let g:pystuff#python_buf = a:python_buf
    let g:pystuff#outline_buf = a:outline_buf

    exec "py3file " . s:spath . "/Outline.py"

endfunction

function pystuff#jump(python_buffer)
    let l:current_line = getline('.')
    let l:number_start = match(l:current_line, "\\d", 0, 1)
    let l:number_end = match(l:current_line, "\\d\\+\\zs", 0, 1) - 1
    if number_start == -1
        return
    endif
    let l:line_nr = str2nr(l:current_line[l:number_start : l:number_end])
    echo l:line_nr

    let l:win = win_findbuf(a:python_buffer)[0]

    call win_gotoid(l:win)
    exec l:line_nr
    
endfunction

function pystuff#outline_setup(python_buf, outline_buf)

    nnoremap <C-J> :call pystuff#jump(b:python_buffer)<cr>

    set syntax=python
endfunction

""
" Makes a new window to the right, which is the bind to the current window.
" At the start, setup and update are called, then every time you write the 
" file, update is called.
function! pystuff#bind(setup, update, bufname, id)
    let l:python_buffer = bufnr("%")
    let l:python_win = winnr()

    botright 40 vnew
    let l:outline_buf = bufnr("%")

    exec l:python_buffer . "b"

    if exists("b:outline_bufs")
        let b:outline_bufs += [l:outline_buf]
    else
        let b:outline_bufs = [l:outline_buf]
    end

    if exists("b:updates")
        let b:updates += [a:update]
    else
        let b:updates = [a:update]
    end

    exec "augroup " . fnameescape(a:id . bufname(l:python_buffer))
        autocmd BufWritePost <buffer> for i in range(len(b:updates)) | call b:updates[i](bufnr("%"), b:outline_bufs[i]) | endfor
    augroup END

    exec l:outline_buf . "b"
    let b:python_buffer = l:python_buffer
    call win_gotoid(l:python_win)

    call a:update(l:python_buffer, l:outline_buf)

    set nowrap
    silent exec ":file " . fnameescape(a:bufname) . "#"

    call a:setup(l:python_buffer, l:outline_buf)

    autocmd BufLeave <buffer> call pystuff#bind_remove(bufnr("%"), b:python_buffer)

endfunction

function pystuff#bind_remove(bind_buf, python_buf)
    exec "sp|" . a:python_buf . "b"
    let l:idx = index(b:outline_bufs, a:bind_buf)
    call remove(b:outline_bufs, l:idx)
    call remove(b:updates, l:idx)
    exec a:bind_buf . "bw!"
    q
endfunction

""
" Opens an outline for the current file.
" The outline is a window containing the line numbers of all assignments,
" function and class definitions. Every time the current file is written, the
" outline is updated. If the cursor is on a line, CTRL-J or S-Enter will jump
" to that place in the file.
function! pystuff#Outline()
     call pystuff#bind(function("pystuff#outline_setup"), function("pystuff#outline_update"), g:pystuff#outline_file_name, "outline")
endfunction

nnoremap <leader>pp :call pystuff#Pep()<cr>
nnoremap <leader>po :call pystuff#Outline()<cr>

