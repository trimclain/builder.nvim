# builder.nvim
Simple building plugin for neovim inspired by the Build Tool from Sublime Text.


## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
    "trimclain/builder.nvim",
    -- stylua: ignore
    keys = {
        { "<C-b>", function() require("builder").build() end, desc = "Build" }
    },
    config = true,
}
```


## Configuration

Following is the default configuration
```lua
{
    position = "bot", -- "bot, top or vert"
    size = 10, -- size in lines for position = "bot" and in characters for position = "vert"
    line_no = false, -- show line numbers in build buffer
    autosave = true, -- automatically save before building
    enable_internals = true, -- use neovim's internal `:source %` on lua and vim files
    commands = {},
}
```
When creating a command, there are following available variables
- `%` or `$file` — current file
- `$basename` — basename of the file
- `$path` — full path to the file
- `$dir` — current working directory
- `$ext` — current file extension

This is an example of what `commands` could look like
```lua
    commands = {
        c = "gcc % -o $basename.out && ./$basename.out",
        cpp = "g++ % -o $basename.out && ./$basename.out",
        go = "go run %",
        java = "java %",
        javascript = "node %",
        -- lua = "lua %", -- this will overwrite enable_internals
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
