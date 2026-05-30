" Oldfiles Improved
" Author:  Austin W. Smith
" Version: 1.1

" Credit: Some code adapted from the yegappan's MRU plugin.
" Source: https://github.com/yegappan/mru
" License under ../LICENSES/

let s:plugin_win_height = 10
" put plugin data files wherever vimrc is located.
let s:plugin_data_dir = fnamemodify(expand($MYVIMRC), ':h') .'/oldfiles-improved/'
let s:plugin_data_file = s:plugin_data_dir . 'recent_files.txt'
let s:plugin_temp_name = 'open-recent'. rand()
let s:plugin_buf_name = '-- Recent Files --'
let s:plugin_locked = 0 " for not reading files during vimgrep
let s:recent_files_list = []
let s:float_win_id = -1

" VARIABLES FOR USER SETTINGS:
" ============================

" If enabled, backslashes will be converted to forward slashes in the recent files list
" This helps to prevent duplicate files (e.g. C:\file\foo and C:/file/foo)
" |
" (Windows only)
if !exists('g:oldfiles_improved_convert_backslashes')
  let g:oldfiles_improved_convert_backslashes = 1
endif

" If disabled, plugin will use a split window instead of a floating window
" |
" (Neovim only)
if has('nvim') && !exists('g:oldfiles_improved_use_floating_window')
  let g:oldfiles_improved_use_floating_window = 1
endif

" If enabled, then recent file list is specially formatted
" Format: filename > path/to/file
if !exists('g:oldfiles_improved_fancy_display')
  let g:oldfiles_improved_fancy_display = 1
endif

" Sets the maximum number of recent files in the list, for performance
if !exists('g:oldfiles_improved_max_files')
  let g:oldfiles_improved_max_files = 1000
endif

" SCRIPT FUNCTIONS:
" =================

" For windows, convert backslashes to forward slashes
fun! s:win_path_fix(path)
  if !has('win32') || !g:oldfiles_improved_convert_backslashes
    return a:path
  endif
  return substitute(a:path, '\', '/', 'g')
endfun

" Create a Neovim floating window.
if has('nvim')
  fun! s:create_floating_win()
    let buf_nr = bufexists(s:plugin_buf_name) ?
          \ bufnr(s:plugin_buf_name) : nvim_create_buf(v:false, v:false)
    call nvim_buf_set_name(buf_nr, s:plugin_temp_name)
    " setlocal noswapfile to suppress error about creating a swapfile
    call nvim_set_option_value('swapfile', v:false,
          \                    {'scope' : 'local', 'buf' : buf_nr })
    call nvim_buf_set_name(buf_nr, s:plugin_buf_name)
    let winwidth = min([120, &columns-(&columns/3)])
    let opts = {
          \ 'relative': 'editor',
          \ 'width': winwidth,
          \ 'height': s:plugin_win_height,
          \ 'col': (&columns - winwidth) / 2,
          \ 'row': (&lines - s:plugin_win_height) / 2,
          \ 'border': 'single',
          \ 'title': s:plugin_buf_name
          \ }
    let s:float_win_id = nvim_open_win(buf_nr, v:true, opts)
    call nvim_set_option_value('winhl', 'Normal:MyHighlight', {'win': s:float_win_id})
    setlocal statusline=
  endfun
endif

" Get recent files window number
" like bufwinnr() but also works with floating window
fun! s:get_plugin_winnr()
  let winid = 0
  if has('nvim') && g:oldfiles_improved_use_floating_window
    let winid = win_id2win(s:float_win_id)
    if winid == 0 | let winid = -1 | endif
  else
    let winid = bufwinnr(s:plugin_buf_name)
  endif
  return winid
endfun

" Check if the current active window is the recent files list
fun! s:is_plugin_window_focused()
  return winnr() == s:get_plugin_winnr()
endfun

" Buffer-local mappings for the plugin window
fun! s:create_local_buffer_maps()
  nnoremap <silent> <buffer> <cr> :call oldfiles_improved#open_file('edit')<cr>
  nnoremap <silent> <buffer> s    :call oldfiles_improved#open_file('split')<cr>
  nnoremap <silent> <buffer> v    :call oldfiles_improved#open_file('vsplit')<cr>
  nnoremap <silent> <buffer> t    :call oldfiles_improved#open_file('tabedit')<cr>
  nnoremap <silent> <buffer> dd   :call oldfiles_improved#remove_file()<cr>
  nnoremap <silent> <buffer> q    :call oldfiles_improved#close_menu()<cr>
  exec 'nmap <silent> <buffer> R q:edit '. expand(s:plugin_data_file) .'<cr>'
endfun

" AUTOLOAD FUNCTIONS:
" ========================

fun! oldfiles_improved#init()
  " Create data folder and file if they don't exist
  if !isdirectory(s:plugin_data_dir)
    call mkdir(s:plugin_data_dir)
  endif
  if !filereadable(s:plugin_data_file)
    call writefile([], s:plugin_data_file)
  else
    " Read recent files into script list
    let s:recent_files_list = readfile(s:plugin_data_file)
  endif

  " Setup autocommands
  augroup oldfiles_improved_plugin
    au!
    au BufRead * call oldfiles_improved#add_current_file()
    au BufWritePost * call oldfiles_improved#add_current_file()
    au BufEnter * call oldfiles_improved#add_current_file()

    " Prevent :vimgrep from adding unneeded files to the list
    autocmd QuickFixCmdPre *vimgrep* let s:plugin_locked = 1
    autocmd QuickFixCmdPost *vimgrep* let s:plugin_locked = 0
  augroup END
endfun

" Limit recent files to max length, and then write to data file
fun! oldfiles_improved#save()
  let s:recent_files_list = s:recent_files_list[: g:oldfiles_improved_max_files-1]
  call writefile(s:recent_files_list, s:plugin_data_file)
endfun

" Add the current file to the recent files list
fun! oldfiles_improved#add_current_file()
  if s:plugin_locked || s:is_plugin_window_focused() | return | endif

  " skip non-files
  let current_file = s:win_path_fix(expand('%:p'))
  if !filereadable(current_file) | return | endif

  " if user is manually editing recent files list, read their changes
  if current_file == s:win_path_fix(s:plugin_data_file)
    let s:recent_files_list = readfile(s:plugin_data_file)
  endif

  " skip special buffer types (usually used by plugins)
  if !empty(&buftype) | return | endif

  " remove file from list if already listed
  call filter(s:recent_files_list, 'v:val !=# current_file')

  " add file to top of list, and save
  call insert(s:recent_files_list, current_file, 0)

  " save changes to list
  call oldfiles_improved#save()
endfun

" Removes a file from the recent files list
fun! oldfiles_improved#remove_file()
  if !s:is_plugin_window_focused() | return | endif

  " remove file from list, then save to file
  let line_num = line('.') - 1
  let line = remove(s:recent_files_list, line_num)
  call oldfiles_improved#save()

  " update plugin window buffer
  setlocal modifiable
  call deletebufline(s:plugin_buf_name, line_num+1)
  setlocal nomodifiable
endfun

" Opens a file from the recent files list:
fun! oldfiles_improved#open_file(edit_cmd)
  let selected_file = s:win_path_fix(s:recent_files_list[line('.')-1])

  if !filereadable(selected_file)
    echohl WarningMsg | echo 'Error: Cannot find file.' | echohl None
  endif

  " close menu and edit file
  if s:is_plugin_window_focused()
    call oldfiles_improved#close_menu()
  endif
  exec 'silent! keepalt '.a:edit_cmd.' '. selected_file
  silent! normal! g`"
endfun

fun! oldfiles_improved#open_menu()
  if s:is_plugin_window_focused() | return | endif

  " read recent files from storage
  let s:recent_files_list = readfile(s:plugin_data_file)
  let s:recent_files_list = s:recent_files_list[: g:oldfiles_improved_max_files-1]

  " nvim allows a floating window,
  if has('nvim') && g:oldfiles_improved_use_floating_window
    call s:create_floating_win()
  else " otherwise open a short window on the bottom (similar to the quickfix list)
    exec 'keepalt botright '. s:plugin_win_height .'split '. s:plugin_temp_name
    " setlocal noswapfile to suppress error about creating a swapfile
    setlocal noswapfile
    exec 'keepalt file '. s:plugin_buf_name
  endif

  setlocal filetype=oldfiles_improved
  setlocal buftype=nofile bufhidden=wipe
  setlocal winfixheight

  " display recent files in the plugin window
  exec 'silent! keepalt read '. s:plugin_data_file
  1delete _

  if g:oldfiles_improved_fancy_display
    for i in range(1, line('$'))
      let line = getline(i)
      let filename = fnamemodify(line, ':t')
      let path = fnamemodify(line, ':p:h')
      call setline(i, filename. ' > ' .path)
      syntax match OldfilesImprovedFileName '^.\{-}\ze>'
      highlight default link OldfilesImprovedFileName Identifier
    endfor
  endif

  setlocal nomodifiable

  call s:create_local_buffer_maps()

endfun

fun! oldfiles_improved#close_menu()
  " switch to previous window
  if s:is_plugin_window_focused()
    wincmd p
  endif

  " close plugin window
  silent! exec s:get_plugin_winnr() .'wincmd c'

  " check for error
  if s:get_plugin_winnr() != -1
    echohl WarningMsg | echo 'Error: Cannot close recent files window.' | echohl None
  endif
endfun

fun! oldfiles_improved#toggle_menu()
  if s:get_plugin_winnr() == -1
    call oldfiles_improved#open_menu()
  else
    call oldfiles_improved#close_menu()
  endif
endfun

