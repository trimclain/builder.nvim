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

--- Complete arguments for :Build.
---@param arg_lead string Argument fragment under the cursor
---@param cmd_line string Full command line
---@param cursor_pos number Cursor position in the command line
---@return string[]
local function complete_build(arg_lead, cmd_line, cursor_pos)
    local keys = { "type", "size", "color", "alt" }
    local values = {
        type = { "bot", "top", "vert", "float" },
        color = { "true", "false" },
        alt = { "true", "false" },
        size = { "0.25", "0.5", "0.75" },
    }

    -- Only consider text before the cursor. Earlier arguments may already
    -- contain a key that should not be suggested again.
    local before_cursor = cmd_line:sub(1, cursor_pos)
    local before_arg = before_cursor:sub(1, #before_cursor - #arg_lead)
    local used = {}

    for key in before_arg:gmatch("(%w+)=[^%s]+") do
        used[key] = true
    end

    local candidates = {}
    local key, value_lead = arg_lead:match("^([^=]+)=(.*)$")

    if key then
        for _, value in ipairs(values[key] or {}) do
            local candidate = key .. "=" .. value
            if value:sub(1, #value_lead) == value_lead then
                candidates[#candidates + 1] = candidate
            end
        end
    else
        for _, option in ipairs(keys) do
            local candidate = option .. "="
            if not used[option] and candidate:sub(1, #arg_lead) == arg_lead then
                candidates[#candidates + 1] = candidate
            end
        end
    end

    return candidates
end

function M.setup(opts)
    -- Check nvim version
    if vim.fn.has("nvim-0.9.0") == 0 then
        Util.error("Builder requires Neovim 0.9.0 or greater")
        return
    end

    config = vim.tbl_deep_extend("force", config, opts or {})

    -- Create the `:Build` command
    vim.api.nvim_create_user_command("Build", function(cmd)
        local parsed = Util.parse(cmd.args)
        if not parsed then
            return
        end

        local options = Util.validate_opts(parsed)
        if options then
            M.build(options)
        end
    end, {
        nargs = "*",
        desc = "Build",
        complete = complete_build,
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
---@param type string bot, top, vert or float
---@param size number amount of lines for type = "bot" / characters for type = "vert"
---@return number bufnr the number of the created buffer
local function create_buffer(type, size)
    local bufnr
    local winid
    if type == "float" then
        bufnr = vim.api.nvim_create_buf(false, true)
        local dimensions = Util.calculate_float_dimensions(config.float_size)
        winid = vim.api.nvim_open_win(bufnr, true, {
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
        vim.cmd(type .. " " .. calc_size .. "new")
        bufnr = vim.api.nvim_get_current_buf()
        vim.bo[bufnr].buflisted = false
        vim.wo.fillchars = "eob: " -- disable ~ on empty lines
        vim.wo.listchars = "trail: " -- don't show trailing whitespaces

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
    Util.create_resize_autocmd(winid or 0, type, size, config)
    set_keymaps(bufnr)
    return bufnr
end

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

--- Measure time passed since start time and return a message
---@param start_time number start time
---@param exit_code number exit code of the last command
---@return string message with the time it took to build
local function measure(start_time, exit_code)
    local seconds = vim.fn.reltimefloat(vim.fn.reltime(start_time))

    local timestring
    if seconds < 1 then
        timestring = string.format("%.0f", seconds * 1000) .. "ms"
    else
        timestring = string.format("%.1f", seconds) .. "s"
    end

    if exit_code ~= 0 then
        return "[Finished in " .. timestring .. " with exit code " .. exit_code .. "]"
    end
    return "[Finished in " .. timestring .. "]"
end

--- Run the command and append the output to the buffer
---@param command string command to run
---@param type string bot, top, vert or float
---@param size number amount of lines for type = "bot" / characters for type = "vert"
local function run_command(command, type, size)
    local bufnr = create_buffer(type, size)
    local start_time = config.measure_time and vim.fn.reltime()

    local obj = vim.system(
        vim.list_extend(vim.split(vim.o.shell, " "), vim.list_extend(vim.split(vim.o.shellcmdflag, " "), { command })),
        { text = true }
    ):wait()

    local data = obj.stdout ~= "" and obj.stdout or obj.stderr or ""
    if data ~= "" then
        local datatable = vim.split(vim.trim(data), "\n")
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, add_padding(datatable, "data"))
    end

    if config.measure_time then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, add_padding({ measure(start_time, obj.code) }, "time"))
    end

    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

--- Run the command and append the output to the buffer
--- This is the legacy version that uses vim.fn.jobstart for nvim < 0.10
---@param command string command to run
---@param type string bot, top, vert or float
---@param size number amount of lines for type = "bot" / characters for type = "vert"
local function legacy_run_command(command, type, size)
    local bufnr = create_buffer(type, size)

    local function append_data_to_buffer(_, data)
        if data then
            -- stylua: ignore
            data = vim.tbl_filter(function(item) return item ~= "" end, data)
            if not vim.tbl_isempty(data) then
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, add_padding(data, "data"))
            end
        end
    end

    local start_time = config.measure_time and vim.fn.reltime()
    local job_id = vim.fn.jobstart(command, {
        stdout_buffered = true,
        on_stdout = append_data_to_buffer,
        on_stderr = append_data_to_buffer,
    })
    local code = vim.fn.jobwait({ job_id })[1]

    if config.measure_time then
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, add_padding({ measure(start_time, code) }, "time"))
    end

    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

--- Run the command in a terminal
---@param type string bot, top, vert or float
---@param size number amount of lines for type = "bot" / characters for type = "vert"
---@param cmd string command to run
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
    local options = Util.validate_opts(opts)
    if not options then
        return
    end

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
    if options.alt ~= nil then
        alt = options.alt
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
    local type = options.type or config.type
    local size = options.size or config.size

    -- handle colored output using `:terminal`
    local color = config.color
    if options.color ~= nil then
        color = options.color
    end
    if color then
        run_in_term(type, size, cmd)
        return
    end

    -- build/run the buffer
    -- if vim.system
    if vim.fn.has("nvim-0.10") == 1 then
        run_command(cmd, type, size)
    else
        legacy_run_command(cmd, type, size)
    end
end

return M
