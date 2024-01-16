local M = {}

local Util = require("builder.util")

local config = {
    type = "bot", -- "bot", "top", "vert" or "float"
    size = 0.25, -- percentage of width/height for type = "vert"/"bot" between 0 and 1
    float_size = {
        height = 0.8,
        width = 0.8,
    },
    float_border = "none", -- which border to use for the floating window from `:h nvim_open_win`
    padding = 0, -- number or table { above, right, below, left }, similar to CSS padding
    line_number = false, -- show line numbers in the Builder buffer
    autosave = true, -- automatically save before building
    close_keymaps = { "q", "<Esc>" }, -- keymaps to close the Builder buffer
    measure_time = true, -- measure the time it took to build
    time_to_data_padding = 0, -- padding between the measured time and the output data
    color = false, -- support colorful output by using to `:terminal`
    -- for lua and vim filetypes `:source %` will be used by default
    commands = {}, -- -- commands for building each filetype, can be a string or a table { cmd = "cmd", alt = "cmd" }
}

function M.setup(opts)
    -- Check nvim version
    if vim.fn.has("nvim-0.9.0") == 0 then
        Util.error("Builder requires Neovim 0.9.0 or greater")
        return
    end

    config = vim.tbl_deep_extend("force", config, opts or {})

    -- Create the `:Build` command
    vim.api.nvim_create_user_command("Build", function(cmd)
        local options = Util.validate_opts(Util.parse(cmd.args))
        if options then
            M.build(options)
        end
    end, {
        nargs = "?",
        desc = "Build",
    })
end

--- Set mapping for closing the Builder buffer
---@param bufnr number buffer number
local function set_keymaps(bufnr)
    for _, key in ipairs(config.close_keymaps) do
        vim.keymap.set("n", key, function()
            vim.api.nvim_win_close(0, true)
        end, { buffer = bufnr, silent = true })
    end
end

--- Create a buffer for the Builder
---@param type string "bot", "top", "vert" or "float"
---@param size number amount of lines for type = "bot" / characters for type = "vert"
---@return number bufnr the number of the created buffer
local function create_buffer(type, size)
    local bufnr
    if type == "float" then
        bufnr = vim.api.nvim_create_buf(false, true)
        local dimensions = Util.calculate_float_dimensions(config.float_size)
        vim.api.nvim_open_win(bufnr, true, {
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
        if config.line_number then
            vim.opt_local.number = true
        end
    else
        local calc_size = Util.calulate_win_size(type, size)
        -- create the window
        -- TODO: this can be more pretty
        vim.cmd(type .. " " .. calc_size .. "new")
        bufnr = vim.api.nvim_get_current_buf()
        vim.bo[bufnr].buflisted = false
        vim.wo.fillchars = "eob: " -- disable ~ on empty lines

        -- make the buffer temporary
        vim.opt_local.buftype = "nofile"
        vim.opt_local.bufhidden = "hide"
        vim.opt_local.swapfile = false

        if not config.line_number then
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
        end
    end
    vim.api.nvim_set_option_value("filetype", "Builder", { buf = bufnr })
    Util.create_resize_autocmd(0, type, size, config)
    set_keymaps(bufnr)
    return bufnr
end

--- Measure time passed since start time and append it to the buffer
--- Return a list of lines with the padding added
--- Credit: https://github.com/nvim-lua/plenary.nvim
---@param replacement table list of strings
---@param data_type? string data or time
---@return table
local function add_padding(replacement, data_type)
    -- padding    List with numbers, defining the padding
    --     above/right/below/left of the popup (similar to CSS).
    --     An empty list uses a padding of 0 all around.  The
    --     padding goes around the text, inside any border.
    --     Padding uses the 'wincolor' highlight.
    --     Example: [1, 2, 1, 3] has 1 line of padding above, 2
    --     columns on the right, 1 line below and 3 columns on
    --     the left.
    local pad_top, pad_right, pad_below, pad_left = 0, 0, 0, 0
    if type(config.padding) == "number" then
        pad_top = config.padding
        pad_right = config.padding
        pad_below = config.padding
        pad_left = config.padding
    elseif type(config.padding) == "table" then
        pad_top = config.padding[1] or 0
        pad_right = config.padding[2] or 0
        pad_below = config.padding[3] or 0
        pad_left = config.padding[4] or 0
    else
        Util.error("The option `padding` can be either a number or a table")
    end

    if data_type == "data" then
        pad_below = 0
    elseif data_type == "time" then
        pad_top = config.time_to_data_padding
    end

    local left_padding = string.rep(" ", pad_left)
    local right_padding = string.rep(" ", pad_right)
    for index = 1, #replacement do
        replacement[index] = string.format("%s%s%s", left_padding, replacement[index], right_padding)
    end

    for _ = 1, pad_top do
        table.insert(replacement, 1, "")
    end

    for _ = 1, pad_below do
        table.insert(replacement, "")
    end

    return replacement
end
---@param start_time number start time
---@param code number exit code of the last command
---@param bufnr number number of buffer to append the output to
local function measure(start_time, code, bufnr)
    local seconds = vim.fn.reltimefloat(vim.fn.reltime(start_time))

    local timestring = ""
    if seconds < 1 then
        timestring = string.format("%.0f", seconds * 1000) .. "ms"
    else
        timestring = string.format("%.1f", seconds) .. "s"
    end

    local message = ""
    if code ~= 0 then
        message = "[Finished in " .. timestring .. " with exit code " .. code .. "]"
    else
        message = "[Finished in " .. timestring .. "]"
    end
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { message })
end

--- Run the command and append the output to the buffer
---@param command string command to run
---@param bufnr number number of buffer to append the output to
local function run_command(command, bufnr)
    local cmdtable = vim.split(command, "&&")
    local code
    local start_time = config.measure_time and vim.fn.reltime()
    for _, cmd in ipairs(cmdtable) do
        ---@diagnostic disable-next-line: missing-fields
        local obj = vim.system(vim.split(vim.trim(cmd), " "), { text = true }):wait()
        local data = obj.stdout ~= "" and obj.stdout or obj.stderr or ""
        code = obj.code
        if data ~= "" then
            local datatable = vim.split(vim.trim(data), "\n")
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, add_padding(datatable, "data"))
        end
        if code ~= 0 then
            break
        end
    end

    if config.measure_time then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, add_padding({ measure(start_time, code) }, "time"))
    end

    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

--- Run the command and append the output to the buffer
--- This is the legacy version that uses vim.fn.jobstart for nvim < 0.10
---@param command string command to run
---@param bufnr number number of buffer to append the output to
local function legacy_run_command(command, bufnr)
    local function append_data_to_buffer(_, data)
        if data then
            -- stylua: ignore
            data = vim.tbl_filter(function(item) return item ~= "" end, data)
            if not vim.tbl_isempty(data) then
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, add_padding(data, "data"))
            end
        end
    end

    local cmds = vim.split(command, "&&")
    local code
    local start_time = config.measure_time and vim.fn.reltime()
    for _, cmd in ipairs(cmds) do
        local job_id = vim.fn.jobstart(vim.split(vim.trim(cmd), " "), {
            stdout_buffered = true,
            on_stdout = append_data_to_buffer,
            on_stderr = append_data_to_buffer,
        })
        code = vim.fn.jobwait({ job_id })[1]
        if code ~= 0 then
            break
        end
    end

    if config.measure_time then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, add_padding({ measure(start_time, code) }, "time"))
    end

    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

--- Run the command in a terminal
---@param type string "bot", "top", "vert" or "float"
---@param size number amount of lines for type = "bot" / characters for type = "vert"
---@param cmd string command to run
-- TODO: somehow combine with create_buffer?
local function run_in_term(type, size, cmd)
    if type == "float" then
        Util.error("type `float` is not supported with `color`")
        return
    end

    local calc_size = Util.calulate_win_size(type, size)
    vim.cmd(type .. " " .. calc_size .. "new | term " .. cmd)

    vim.opt_local.buflisted = false
    if not config.line_number then
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end

    vim.api.nvim_set_option_value("filetype", "Builder", { scope = "local" })
    Util.create_resize_autocmd(0, type, size, config)
    set_keymaps(vim.api.nvim_get_current_buf())
end

function M.build(opts)
    opts = Util.validate_opts(opts)

    if not vim.bo.buflisted then
        Util.info("Building unlisted buffers is not supported")
        return
    elseif not vim.bo.modifiable then
        Util.info("Building unmodifiable buffers is not supported")
        return
    end

    -- before building
    if config.autosave then
        vim.cmd("silent write")
    end

    local filetype = vim.bo.filetype
    local cmd = config.commands[filetype]

    -- handle internal commands
    local is_internal = vim.tbl_contains({ "lua", "vim" }, filetype)
    if is_internal and not cmd then
        vim.cmd.source("%")
        return
    end

    if not cmd then
        Util.info('Building "' .. filetype .. '" is not configured')
        return
    end

    -- parse cmd
    local alt = false
    if opts.alt ~= nil then
        alt = opts.alt
    end

    if type(cmd) == "table" then
        if alt then
            cmd = cmd.alt
        else
            cmd = cmd.cmd
        end
        cmd = Util.substitute(cmd)
    elseif type(cmd) == "string" then
        if alt then
            Util.error('Alt command for "' .. filetype .. '" not found')
            return
        end
        cmd = Util.substitute(cmd)
    else
        Util.error('Command for "' .. filetype .. '" can be either a string or table')
        return
    end

    -- preconfigure Builder buffer
    local type = opts.type or config.type
    local size = opts.size or config.size

    -- handle colored output using `:terminal`
    local color = config.color
    if opts.color ~= nil then
        color = opts.color
    end
    if color then
        run_in_term(type, size, cmd)
        return
    end

    -- build/run the buffer
    local bufnr = create_buffer(type, size)
    -- if vim.system
    if vim.fn.has("nvim-0.10") == 1 then
        run_command(cmd, bufnr)
    else
        legacy_run_command(cmd, bufnr)
    end
end

return M
