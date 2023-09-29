# builder.nvim
Simple building plugin for neovim inspired by the Build Tool from Sublime Text.


## Demo

https://github.com/trimclain/builder.nvim/assets/84108846/d412e43e-f19a-4a1e-95a6-1bf53d18d227


## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim) *(recommended)*
```lua
{
    "trimclain/builder.nvim",
    cmd = "Build",
    -- stylua: ignore
    keys = {
        { "<C-b>", function() require("builder").build() end, desc = "Build" }
    },
    config = true,
}
```
Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
    "trimclain/builder.nvim",
    config = function()
        require('builder').setup()
        vim.keymap.set("n", "<C-b>", ":Build<cr>", { silent = true, desc = "Build" })
    end
}
```


## Configuration

Builder comes with the following defaults:
```lua
{
    -- location of Builder buffer; opts: "bot", "top", "vert" or float
    type = "bot",
    -- percentage of width/height for type = "vert"/"bot" between 0 and 1
    size = 0.25,
    -- size of the floating window for type = "float"
    float_size = {
        height = 0.8,
        width = 0.8,
    },
    -- which border to use for the floating window (see `:help nvim_open_win`)
    float_border = "none",
     -- show/hide line numbers in the Builder buffer
    line_number = false,
    -- automatically save before building
    autosave = true,
    -- keymaps to close the builder buffer, same format as for vim.keymap.set
    close_keymaps = { "q", "<Esc>" },
    -- use neovim's built-in `:source %` for *.lua and *.vim
    enable_builtin = true,
    -- commands for building each filetype; see below
    commands = {},
}


```
When creating a command, there are following available variables
- `%` — path to the current file from the current working directory
- `$file` — current file name with extension
- `$basename` — basename of the file
- `$ext` — current file extension
- `$path` — full path to the file
- `$dir` — current working directory

This is an example of what `commands` could look like
```lua
    commands = {
        c = "gcc % -o $basename.out && ./$basename.out",
        cpp = "g++ % -o $basename.out && ./$basename.out",
        go = "go run %",
        java = "java %",
        javascript = "node %",
        -- lua = "lua %", -- this will override enable_builtin for lua
        markdown = "glow %",
        python = "python %",
        rust = "cargo run",
        sh = "sh %",
        typescript = "ts-node %",
        zsh = "zsh %",
    },
```

## Usage
Run `:Build` to build/run current file/project using the command from `commands` table.
You can also pass different `size` and `position` arguments:
```
:Build size=35 position=vert
```
or
```
:lua require("builder").build({ size = 35, position = "vert" })
```


## Credit

- [jaq.nvim](https://github.com/is0n/jaq-nvim) -- for giving me motivation to do it better
- [tj's video](https://www.youtube.com/watch?v=9gUatBHuXE0) -- for showing me how to do it better
