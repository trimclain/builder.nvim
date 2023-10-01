local M = {}

local Util = require("builder.util")

local config = {
    type = "bot", -- "bot", "top", "vert" or "float"
    -- number of lines for type = "bot" / characters for type = "vert"
    size = 0.25, -- percentage of width/height for type = "vert"/"bot" between 0 and 1
    float_size = {
        height = 0.8,
        width = 0.8,
    },
    float_border = "none", -- which border to use for the floating window from `:h nvim_open_win`
    line_number = false, -- show line numbers the builder buffer
    autosave = true, -- automatically save before building
    close_keymaps = { "q", "<Esc>" }, -- keymaps to close the builder buffer
    measure_time = true, -- measure the time it took to build
    -- for lua and vim filetypes `:source %` will be used by default
    commands = {}, -- commands for building each filetype
}

function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})

    -- disable measure_time on windows until a better solution is found
    if vim.fn.has("win32") == 1 or vim.fn.has("mac") == 1 then
        config.measure_time = false
    end

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

--- Set mapping for closing the builder buffer
---@param bufnr number buffer number
local function set_keymaps(bufnr)
    for _, key in ipairs(config.close_keymaps) do
        vim.keymap.set("n", key, function()
            vim.api.nvim_win_close(0, true)
        end, { buffer = bufnr, silent = true })
    end
end

--- Create a buffer for the builder
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

        -- make the buffer temporary
        vim.opt_local.buftype = "nofile"
        vim.opt_local.bufhidden = "hide"
        vim.opt_local.swapfile = false

        if not config.line_number then
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
        end
    end
    Util.create_resize_autocmd(0, type, size, config)
    set_keymaps(bufnr)
    return bufnr
end

--- Run the command and append the output to the buffer
---@param command string command to run
---@param bufnr number number of buffer to append the output to
local function run_command(command, bufnr)
    -- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Output:" })
    local cmdtable = vim.split(command, "&&")
    for _, cmd in ipairs(cmdtable) do
        -- INFO: time measurement uses the external `date` command from (only on linux)

        ---@diagnostic disable-next-line: missing-fields
        local start_time = config.measure_time and vim.system({ "date", "+%s%N" }, { text = true }):wait().stdout or 0

        ---@diagnostic disable-next-line: missing-fields
        local obj = vim.system(vim.split(vim.trim(cmd), " "), { text = true }):wait()
        local data = obj.stdout ~= "" and obj.stdout or obj.stderr or ""
        local datatable = vim.split(vim.trim(data), "\n")
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, datatable)

        ---@diagnostic disable-next-line: missing-fields
        local end_time = config.measure_time and vim.system({ "date", "+%s%N" }, { text = true }):wait().stdout or 0

        if config.measure_time then
            local milliseconds = math.floor((end_time - start_time) / 1000000)
            local message = ""

            if milliseconds >= 1000 then
                local seconds = string.format("%.1f", milliseconds / 1000)
                message = seconds .. "s"
            else
                message = milliseconds .. "ms"
            end

            vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "[Finished in " .. message .. "]" })
        end
    end
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
end

function M.build(opts)
    opts = Util.validate_opts(opts)

    -- before building
    if config.autosave then
        vim.cmd("silent write")
    end

    -- handle internal commands
    local filetype = vim.bo.filetype
    local cmd = config.commands[filetype]
    local is_internal = vim.tbl_contains({ "lua", "vim" }, filetype)
    if is_internal and not cmd then
        vim.cmd.source("%")
        return
    end

    -- parse cmd
    if not cmd then
        Util.info('Building "' .. filetype .. '" is not configured')
        return
    end
    cmd = Util.substitute(cmd)

    -- preconfigure builder buffer
    local type = opts.type or config.type
    local size = opts.size or config.size

    -- build/run the buffer
    local bufnr = create_buffer(type, size)
    run_command(cmd, bufnr)
end

return M
