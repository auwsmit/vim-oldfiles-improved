# Oldfiles Improved

### Like `:oldfiles`, but improved!

A simple toggleable window which lets you select recently used files.
Vim has the built in `:browse oldfiles`, but it is very clunky to use.

Works for Vim and Neovim.

## Installation

Install via your preferred plugin manager, and make a mapping to toggle the
recent files menu:

```vim
" vim-plug vimscript
Plug 'auwsmit/vim-oldfiles-improved'
nnoremap <silent> <Leader>r :call oldfiles_improved#toggle_menu()<CR>
```

```lua
-- lazy.nvim lua
{
  "auwsmit/vim-oldfiles-improved",
  keys = {
    {
      "<leader>r",
      "<cmd>call oldfiles_improved#toggle_menu()<CR>",
      desc = "Oldfiles Improved",
    },
  },
}
```

## How to use

Navigate the list like a normal buffer.

Open a file with `<CR>`.

Remove a file from list with `dd`.

## Settings

Purely optional settings to adjust based on your preferences:

(these are the default values)

```vim
" convert backslashes to forward slashes
" (Windows only)
let g:spear_convert_backslashes = 1

" use floating window intead of split window
" (neovim only)
let g:spear_use_floating_window = 1

" show a fancier recent files list
" format: filename > path/to/file
let g:oldfiles_improved_fancy_display = 1
```

```lua
-- with lua
vim.g.oldfiles_improved_fancy_display = 1
```
