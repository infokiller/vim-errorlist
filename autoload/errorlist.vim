let g:error_list_post_command = get(g:, 'error_list_post_command', '')
let g:error_list_max_items = get(g:, 'error_list_max_items', 10000)

let g:error_list_debug = get(g:, 'error_list_debug', 0)
let g:error_list_use_sort = 1
" The cache is unused for now, since it doesn't always invalidate itself when
" needed.
let g:error_list_max_cache_size = 0
let s:cache = []

augroup error_list
  autocmd!
  " Invalidate the cache.
  " TODO: This isn't triggered when `setqflist` is called, need to figure this
  " out.
  autocmd QuickFixCmdPost * let s:cache = []
augroup END

function! s:Warning(message) abort
  echohl WarningMsg
  echomsg a:message
  echohl None
endfunction

" Given an error position (from quickfix or location list), returns a number
" indication its **logical** relative position to the cursor:
" -1 if the error is before the cursor
" 0 if the error is in the same position as the cursor
" +1 if the error is after the cursor
function! errorlist#PosCompare(lhs, rhs) abort
  if a:lhs.bufnr < a:rhs.bufnr
    return -1
  elseif a:lhs.bufnr > a:rhs.bufnr
    return 1
  endif
  if a:lhs.lnum < a:rhs.lnum
    return -1
  elseif a:lhs.lnum > a:rhs.lnum
    return 1
  endif
  " We're using crewind/lrewind to navigate to specific error items, which
  " mimics typing enter when an item is highlighted in the list. After the
  " navigation command, the cursor won't alway move to the column specified in
  " the error item. Specific issues:
  " 1. When the column in the error item is set to a value smaller than the
  "    column of the first non-blank char on the line, the cursor will move to
  "    the first non-blank char on the line.
  " 2. When the column in the error item is set to a value larger than the
  "    last column of the line, the cursor will move to the last column on the
  "    line. One way this can happen is if a part of a line was deleted after
  "    the error list was generated, making the error list stale.
  " 3. An item can have its column unset or set to 0.
  " Because of this behavior, we consider all items on a line as having a column
  " that is at a minimum the column of the first non-blank char on that line,
  " and at a maximum the number of (unicode) characters in the line.
  " Otherwise the cursor can get stuck when navigating to the previous/next
  " error item.
  let l:line = get(getbufline(a:lhs.bufnr, a:lhs.lnum), 0, '')
  if empty(l:line)
    return 0
  endif
  breakadd here
  let l:min_col = match(l:line, '\m\C\S') + 1
  let l:max_col = len(split(l:line, '\M\zs'))
  let l:lhs_col = min([max([a:lhs.col, l:min_col]), l:max_col])
  let l:rhs_col = min([max([a:rhs.col, l:min_col]), l:max_col])
  if l:lhs_col < l:rhs_col
    return -1
  elseif l:lhs_col > l:rhs_col
    return 1
  endif
  return 0
endfunction

function! s:ErrorListGetNextItem(items, wrap, reverse) abort
  if !empty(s:cache)
    call assert_equal(len(s:cache), len(a:items))
    let l:sorted_items = s:cache
  else
    let l:sorted_items = sort(a:items, 'errorlist#PosCompare')
    if len(a:items) <= g:error_list_max_cache_size
      let s:cache = l:sorted_items
    endif
  endif
  let l:cursor_pos = {'bufnr': bufnr('%'), 'lnum': line('.') ,'col': col('.')}
  let l:first_item = l:sorted_items[0]
  let l:last_item = l:sorted_items[-1]
  let l:cmp = a:reverse ? '-1' : 1
  let l:next_items = filter(copy(l:sorted_items),
      \ 'errorlist#PosCompare(v:val, l:cursor_pos) == l:cmp')
  if !empty(l:next_items)
    if a:reverse
      return l:next_items[-1]
    else
      return l:next_items[0]
    endif
  elseif !a:wrap
    return ''
  elseif a:reverse
    return l:last_item
  else
    return l:first_item
  endif
endfunction

" Implementation that avoids sorting, used only for testing.
" function! s:ErrorListGetNextItem(items, wrap, reverse) abort
"   let l:cursor_pos = {'bufnr': bufnr('%'), 'lnum': line('.') ,'col': col('.')}
"   let l:cmp = a:reverse ? '-1' : 1
"   let l:first_item = a:items[0]
"   let l:last_item = a:items[0]
"   let l:nearest_item = []
"   for l:item in a:items
"     if errorlist#PosCompare(l:item, l:first_item) < 0
"       let l:first_item = l:item
"     elseif errorlist#PosCompare(l:item, l:last_item) > 0
"       let l:last_item = l:item
"     endif
"     if errorlist#PosCompare(l:item, l:cursor_pos) == l:cmp &&
"         \ (empty(l:nearest_item) ||
"         \  errorlist#PosCompare(l:nearest_item, l:item) == l:cmp)
"       let l:nearest_item = l:item
"     endif
"   endfor
"   if !empty(l:nearest_item)
"     return l:nearest_item
"   elseif !a:wrap
"     return ''
"   elseif a:reverse
"     return l:last_item
"   else
"     return l:first_item
"   endif
" endfunction

function s:ExecuteNavigation(cmd) abort
  execute a:cmd
  if get(g:, 'error_list_post_command')
    execute g:error_list_post_command
  endif
endfunction

function s:GetBuiltinCommand(list_type, reverse) abort
  let l:prefix = a:list_type is# 'loc' ? 'l' : 'c'
  let l:suffix = a:reverse ? 'prev' : 'next'
  return l:prefix . l:suffix
endfunction

function! errorlist#Navigate(list_type, wrap, reverse) abort
  if a:list_type is# 'loc'
    let l:items = getloclist(0)
    let l:go_to_error_cmd = 'lrewind!'
  elseif a:list_type is# 'qf'
    let l:items = getqflist()
    let l:go_to_error_cmd = 'crewind!'
  else
    call s:Warning('list_type must be "loc" or "qf"')
    return
  endif
  if empty(l:items)
    call s:Warning('E42: No Errors')
    return
  endif
  if len(l:items) > g:error_list_max_items
    call s:Warning('ErrorList: Too many items, falling back to built-in navigation')
    let l:cmd = s:GetBuiltinCommand(a:list_type, a:reverse)
    call s:ExecuteNavigation(cmd)
    return
  endif
  " Add the one based index to every item so that we can later jump to them with
  " go_to_error_cmd, which requires this index.
  call map(l:items, 'extend(v:val, {"idx": v:key + 1})')
  let l:time = reltime()
  let l:next_item = s:ErrorListGetNextItem(l:items, a:wrap, a:reverse)
  if g:error_list_debug
    echomsg reltimestr(reltime(l:time))
  endif
  if empty(l:next_item)
    call s:Warning('E553: No more items')
  endif
    execute l:go_to_error_cmd . ' ' . l:next_item.idx
    if get(g:, 'error_list_navigation_post_command')
      execute g:error_list_navigation_post_command
    endif
endfunction
