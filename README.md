# Valgrind.vim

[Valgrind](https://www.valgrind.org/) is an open-source memory debugger. This
script allows users to start valgrind from Vim using the `:Valgrind` command,
and easily jump to errors it reports.

Valgrind is usually invoked from the command line, for instance:

```
$ valgrind ./my-program arg1 arg2
```

This plugin allows users to do the same from Vim with the following:

```
:Valgrind ./my-program arg1 arg2
```

This places Valgrind's output in a valgrind buffer, with commands to navigate
the call stack for any errors reported, and [basic syntax highlighting courtesy
of Vim](https://github.com/vim/vim/blob/master/runtime/syntax/valgrind.vim).

## Installation

If you are using [vim-plug](https://github.com/junegunn/vim-plug), you can
install this plugin by adding the following to your .vimrc:

```
Plug 'j-hui/valgrind.vim', { 'branch': 'main' }
```

Source your .vimrc and run `:PlugInstall` from Vim.

## Documentation

See [`:help valgrind.vim`](doc/valgrind.txt) for details.

## Acknowledgements

This is a fork of <http://www.vim.org/scripts/script.php?script_id=607>, by
Rainer M. Schmid, later forked by [LAHumphreys][lahumphreys-valgrind], then
[LucHermitte][luchermitte-valgrind]. LAHumphreys added support for moving up and
down the current call stack and making the plugin behave more sensibly when
re-run (it will attempt to re-run in the same window). LucHermitte added support
for CTest.

This particular fork builds off the aforementioned forks, and tries to
simplify the jumping and splitting behavior, and makes the keybindings and
valgrind buffer hook more configurable.

[lahumphreys-valgrind]: https://github.com/LAHumphreys/valgrind.vim
[luchermitte-valgrind]: https://github.com/luchermitte/valgrind.vim
