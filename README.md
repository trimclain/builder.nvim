# ⚒️ builder.nvim
Simple building plugin for neovim inspired by the Build Tool from Sublime Text.

| Default                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| ![bot](https://github.com/trimclain/builder.nvim/assets/84108846/21bd3b5e-0e33-4e24-b7a3-fa8f63572ffc)                                                                                                             |

| Vertical                                                                                                | Floating                                                                                                 |
| ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| ![vert](https://github.com/trimclain/builder.nvim/assets/84108846/1e2ee23a-6ad1-4a3a-b8b1-893403f5c01c) | ![float](https://github.com/trimclain/builder.nvim/assets/84108846/6f94dc76-b652-4ac8-b54e-c3d19aaebdaa) |


## Demo

https://github.com/trimclain/builder.nvim/assets/84108846/c2468898-e5c6-4786-bf37-9dc780261cc7


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
    opts = {
        commands = {
            -- add your commands
        },
    },
}
```
Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
    "trimclain/builder.nvim",
    config = function()
        require('builder').setup({
            commands = {
                -- add your commands
            },
        })
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
     -- measure the time it took to build (currently enabled only on linux)
    measure_time = true,
    -- support colorful output by using to `:terminal` instead of a normal nvim buffer;
    -- for `color = true` the `type = "float"` isn't allowed
    color = false,
    -- commands for building each filetype; see below
    -- for lua and vim filetypes `:source %` will be used by default
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
        -- lua = "lua %", -- this will override the default `:source %` for lua files
        markdown = "glow %",
        python = "python %",
        rust = "cargo run",
        sh = "sh %",
        typescript = "ts-node %",
        zsh = "zsh %",
    },
```


## Usage

Run `:Build` to build/run current file/project using the command for current filetype from `commands` table.
You can also pass different `size` and `type` arguments:
```
:Build size=0.4 type=vert
```
or
```
:lua require("builder").build({ type = "float" })
```
To enable colored output use:
```
:Build color=true
```


## Feedback

If you have any questions or would like to see any new features, feel free to open a new [Issue](https://github.com/trimclain/builder.nvim/issues). Feedback is very welcome
and greatly appreciated.


## Credit

- [jaq.nvim](https://github.com/is0n/jaq-nvim)
- [tj's video](https://www.youtube.com/watch?v=9gUatBHuXE0)
