scriptencoding utf-8

if exists('g:loaded_errorlist')
  finish
endif
let g:loaded_errorlist = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -bar QuickFixNext call errorlist#Navigate('qf', 1, 0)
command! -bar QuickFixPrev call errorlist#Navigate('qf', 1, 1)
command! -bar LoclistNext call errorlist#Navigate('loc', 1, 0)
command! -bar LoclistPrev call errorlist#Navigate('loc', 1, 1)

let &cpoptions = s:save_cpo
unlet s:save_cpo
