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
    line_no = false, -- show line numbers
    autosave = true, -- automatically save before building
    close_keymaps = { "q" }, -- keymaps to close the builder buffer
    enable_builtin = true, -- use neovim's built-in `:source %` for *.lua and *.vim
    commands = {}, -- commands for building each filetype
}

function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})

    -- TODO: add validate_config()
    -- if not validate(config) then
    --     return
    -- end

    -- Create the `:Build` command
    vim.api.nvim_create_user_command("Build", function(cmd)
        local options = Util.validate(Util.parse(cmd.args))
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
        -- stylua: ignore
        vim.keymap.set("n", key, function() vim.api.nvim_win_close(0, true) end, { buffer = bufnr, silent = true })
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
        local dimensions = Util.get_float_dimensions(config.float_size)
        vim.api.nvim_open_win(bufnr, true, {
            style = "minimal",
            relative = "editor",
            width = dimensions.width,
            height = dimensions.height,
            row = dimensions.row,
            col = dimensions.col,
            -- border = config.ui.float.border,
            -- title = "TESTING",
        })
    else
        size = type == "vert" and math.floor(vim.o.columns * size) or math.floor(vim.o.lines * size)
        -- create the window
        vim.cmd(type .. " " .. size .. "new")
        bufnr = vim.api.nvim_get_current_buf()
        vim.bo[bufnr].buflisted = false

        -- make the buffer temporary
        vim.opt_local.buftype = "nofile"
        vim.opt_local.bufhidden = "hide"
        vim.opt_local.swapfile = false

        if not config.line_no then
            vim.opt_local.number = false
            vim.opt_local.relativenumber = false
        end
    end

    set_keymaps(bufnr)
    return bufnr
end

--- Run the command and append the output to the buffer
---@param cmd string command to run
---@param bufnr number number of buffer to append the output to
local function run_command(cmd, bufnr)
    local function append_data_to_buffer(_, data)
        if data then
            -- stylua: ignore
            data = vim.tbl_filter(function(item) return item ~= "" end, data)
            if not vim.tbl_isempty(data) then
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data)
                -- TODO: calculate timer to show "Finished" after the job is done
                -- vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "Finished TBD ms." })
            end
        end
    end
    -- vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Output:" })
    vim.fn.jobstart(vim.split(cmd, " "), {
        stdout_buffered = true,
        on_stdout = append_data_to_buffer,
        on_stderr = append_data_to_buffer,
    })
end

function M.build(opts)
    opts = Util.validate(opts)

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
