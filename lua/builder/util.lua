local M = {}

-- stylua: ignore start
local notify = function(msg, log_level) vim.notify(msg, log_level, { title = "Builder" }) end
M.info = function(msg) notify(msg, vim.log.levels.INFO) end
M.error = function(msg) notify(msg, vim.log.levels.ERROR) end
-- stylua: ignore end

--- Parse arguments for the `:Build` command
---@param args string arguments from cmd.args (see `:help nvim_create_user_command`)
---@return table opts parsed options to pass to `:Build`
function M.parse(args)
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

--- Validate parsed arguments for the `:Build` command (currently allow only size and type)
---@param opts table parsed arguments from cmd.args (see `:help nvim_create_user_command`)
---@return table|boolean opts validated options to pass to `:Build` or false if there was an error
function M.validate_opts(opts)
    if opts == nil then
        return {}
    end

    -- handle invalid options
    local allowed_opts = { "size", "type" }
    for key, _ in pairs(opts) do
        if not vim.tbl_contains(allowed_opts, key) then
            error("Error: invalid option: " .. key .. "\nAllowed options: " .. vim.inspect(allowed_opts))
            return false
        end
    end
    -- handle invalid type
    if opts.type then
        local allowed_types = { "bot", "top", "vert", "float" }
        local type_valid = false
        for _, type in pairs(allowed_types) do
            if opts.type == type then
                type_valid = true
                break
            end
        end
        if not type_valid then
            error("Error: invalid type: " .. opts.type .. "\nAllowed types: " .. vim.inspect(allowed_types))
            return false
        end
    end

    -- convert size to number (tonumber returns nil if the string is not a number)
    opts.size = opts.size and tonumber(opts.size)
    return opts
end

--- Replace placeholders in the command with actual values
---@param cmd string command with placeholders
---@return string cmd command with placeholders replaced
function M.substitute(cmd)
    -- :t is needed because when you open a file using a file tree, % becomes full path to the file
    cmd = cmd:gsub("%%", vim.fn.expand("%"))
    cmd = cmd:gsub("$file", vim.fn.expand("%:t"))
    cmd = cmd:gsub("$ext", vim.fn.expand("%:e"))
    cmd = cmd:gsub("$basename", vim.fn.expand("%:t:r"))
    cmd = cmd:gsub("$path", vim.fn.expand("%:p"))
    cmd = cmd:gsub("$dir", vim.fn.expand("%:p:h"))
    return cmd
end

--- Get the dimensions of the floating window
---@param float_size table width and height of the floating window
---@return table dimensions of the floating window
function M.calculate_float_dimensions(float_size)
    local x = 0.5
    local y = 0.5

    local columns = vim.o.columns
    local lines = vim.o.lines

    local width = math.ceil(columns * float_size.width)
    local height = math.ceil(lines * float_size.height - 5)
    local row = math.ceil((lines - height) * y - 1)
    local col = math.ceil((columns - width) * x)

    return {
        width = width,
        height = height,
        row = row,
        col = col,
    }
end

--- Calculate the size of the window
---@param type string "bot", "top", or "vert"
---@param size number percentage of the window size
---@return number size amount of lines or columns
function M.calulate_win_size(type, size)
    if type == "vert" then
        return math.floor(vim.o.columns * size)
    else
        return math.floor(vim.o.lines * size)
    end
end

--- Resize window with winid
---@param winid number window id
---@param type string "bot", "top", "vert", or "float"
---@param size number percentage of the window size
---@param config table default builder config
local function resize_window(winid, type, size, config)
    if type == "float" then
        local dimensions = M.calculate_float_dimensions(config.float_size)
        vim.api.nvim_win_set_config(0, {
            style = "minimal",
            relative = "editor",
            width = dimensions.width,
            height = dimensions.height,
            row = dimensions.row,
            col = dimensions.col,
            border = config.float_border,
            title = " Builder ",
            title_pos = "center",
        })
        return
    end

    local calc_size = M.calulate_win_size(type, size)
    if type == "vert" then
        vim.api.nvim_win_set_width(winid, calc_size)
    else
        vim.api.nvim_win_set_height(winid, calc_size)
    end
end

--- Create an autocmd to resize the window with winid
---@param winid number window id
---@param type string "bot", "top", "vert", or "float"
---@param size number percentage of the window size
---@param config table default builder config
function M.create_resize_autocmd(winid, type, size, config)
    vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
            resize_window(winid, type, size, config)
        end,
        desc = "Update builder size when window is resized",
        group = vim.api.nvim_create_augroup("builder_resize", { clear = true }),
    })
end

return M
