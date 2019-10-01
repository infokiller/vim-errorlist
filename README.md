# vim-errorlist

A Vim/Neovim plugin for navigating the quicklist and location lists relative to the current cursor position.

## Installlation

Install using your favourite package manager, or use Vim's built-in package support. Example for [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'infokiller/vim-errorlist'

" On-demand lazy loading
Plug 'infokiller/vim-errorlist', { 'on': ['errorlist#Navigate'] }
```

## Usage

The plugin offers 4 commands:

- `QuickFixPrev`: go to quickfix error before the cursor
- `QuickFixNext`: go to quickfix error after the cursor
- `LoclistPrev`: go to location list error before the cursor
- `LoclistNext`: go to location list error after the cursor

By default, the plugin doesn't do any remappings. Example configuration:

```vim
" Navigate quickfix list with Ctrl+{p,n}
nnoremap <C-p> :QuickFixPrev<cr>
nnoremap <C-n> :QuickFixNext<cr>
" Navigate location list with Alt+{p,n}
nnoremap <M-p> :LoclistPrev<cr>
nnoremap <M-n> :LoclistNext<cr>
```

### Configuration

#### Post navigation command

You can define a command that will be executed right after the navigation. For example, the snippet below will scroll so that the cursor in the center of the window:

```vim
let g:error_list_post_command = 'normal! zz'
```

#### Max items

By default, the plugin will fall back to vim's built in navigation commands (`:cn` etc.) if the number of items is more than 10,000. The reason for this is that navigating relative to the cursor can become slow with a large number of items.
To change the maximum number of items:

```vim
let g:error_list_max_items = 10000
```
