# builder.nvim
Simple building plugin for neovim inspired by the Build Tool from Sublime Text.

## Demo

![image](https://github.com/trimclain/builder.nvim/assets/84108846/e5b7382a-bab1-4a00-93af-8a66f070bc90)



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
    -- location of Builder buffer; opts: "bot", "top" or "vert"
    position = "bot",
    -- number of lines for position = "bot" / characters for position = "vert",
    -- by default the size is 30% of nvim width for "vert" or 25% of height for "bot"
    size = false,
     -- show/hide line numbers in the Builder buffer
    line_no = false,
    -- automatically save before building
    autosave = true,
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

## Credit

- [jaq.nvim](https://github.com/is0n/jaq-nvim)
