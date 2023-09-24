local M = {}

local config = {
    position = "bot", -- "bot, top or vert"
    size = false, -- number of lines for position = "bot" / characters for position = "vert"
    line_no = false, -- show line numbers
    autosave = true, -- automatically save before building
    close_keymaps = { "q" }, -- keymaps to close the builder buffer
    enable_builtin = true, -- use neovim's built-in `:source %` for *.lua and *.vim
    commands = {}, -- commands for building each filetype
}

-- send notifications
-- stylua: ignore start
local notify = function(msg, type) vim.notify(msg, type, { title = "Builder" }) end
local info = function(msg) notify(msg, vim.log.levels.INFO) end
local error = function(msg) notify(msg, vim.log.levels.ERROR) end
-- stylua: ignore end

--- Parse arguments for the `:Build` command
---@param args string arguments from cmd.args (see `:help nvim_create_user_command`)
---@return table opts parsed options to pass to `:Build`
local function parse(args)
    -- remove "Build" from args
    local parts = vim.split(vim.trim(args), "%s+")
    if parts[1]:find("Build") then
        table.remove(parts, 1)
    end
    -- create opts table
    local opts = {}
    for _, arg in pairs(parts) do
        local opt = vim.split(arg, "=")
        opts[opt[1]] = opt[2]
    end
    return opts
end

--- Validate parsed arguments for the `:Build` command
---@param opts table parsed arguments from cmd.args (see `:help nvim_create_user_command`)
---@return table|boolean opts validated options to pass to `:Build` or false if there was an error
local function validate(opts)
    if opts == nil then
        return {}
    end

    -- handle invalid options
    local allowed_opts = { "size", "position" }
    for key, _ in pairs(opts) do
        if not vim.tbl_contains(allowed_opts, key) then
            error("Error: invalid option: " .. key .. "\nAllowed options: " .. vim.inspect(allowed_opts))
            return false
        end
    end
    -- TODO: handle invalid types (e.g. size is not a number)

    -- convert size to number
    opts.size = opts.size and tonumber(opts.size)
    return opts
end

--- Replace placeholders in the command with actual values
---@param cmd string command with placeholders
---@return string cmd command with placeholders replaced
local function substitute(cmd)
    -- :t is needed because when you open a file using a file tree, % becomes full path to the file
    cmd = cmd:gsub("%%", vim.fn.expand("%"))
    cmd = cmd:gsub("$file", vim.fn.expand("%:t"))
    cmd = cmd:gsub("$ext", vim.fn.expand("%:e"))
    cmd = cmd:gsub("$basename", vim.fn.expand("%:t:r"))
    cmd = cmd:gsub("$path", vim.fn.expand("%:p"))
    cmd = cmd:gsub("$dir", vim.fn.expand("%:p:h"))
    return cmd
end

local function set_keymaps(buf)
    for _, key in ipairs(config.close_keymaps) do
        vim.keymap.set("n", key, "<cmd>close<cr>", { buffer = buf, silent = true })
    end
end

function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
    local default_size
    -- make size 30% of width for "vert" or 25% of height for "bot"
    if config.position == "vert" then
        default_size = math.floor(vim.o.columns * 0.3)
    else
        default_size = math.floor(vim.o.lines * 0.25)
    end
    config.size = opts.size or default_size

    -- Create the `:Build` command
    vim.api.nvim_create_user_command("Build", function(cmd)
        local options = validate(parse(cmd.args))
        if options then
            M.build(options)
        end
    end, {
        nargs = "?",
        desc = "Build",
    })
end

function M.build(opts)
    opts = validate(opts)

    -- before building
    if config.autosave then
        vim.cmd("silent write")
    end

    -- handle internal commands
    local filetype = vim.bo.filetype
    local cmd = config.commands[filetype]
    local is_internal = config.enable_builtin and vim.tbl_contains({ "lua", "vim" }, filetype)
    if is_internal and not cmd then
        vim.cmd("source %")
        return
    end

    -- parse cmd
    if not cmd then
        info('Building "' .. filetype .. '" is not configured')
        return
    end
    cmd = substitute(cmd)

    -- preconfigure builder buffer
    local position = opts.position or config.position
    local size = opts.size or config.size

    -- build/run the buffer
    vim.cmd(position .. " " .. size .. "new | term " .. cmd)

    -- configure created buffer
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buflisted = false
    set_keymaps(buf)
    if not config.line_no then
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end
end

return M
