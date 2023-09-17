local M = {}

local config = {
    position = "bot", -- "bot, top or vert"
    size = 10, -- size in lines for position = "bot" and in characters for position = "vert"
    line_no = false, -- show line numbers
    autosave = true, -- automatically save before building
    enable_internals = true, -- use neovim's internal `:luafile %` and `:source %`
    commands = {},
}

function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
end

--- Use vim.notify to send INFO notifications
---@param msg string
local info = function(msg)
    vim.notify(msg, vim.log.levels.INFO, { title = "Builder" })
end

local function substitute(cmd)
    -- :t is needed because when you open a file using a file tree, % becomes full path to the file
    cmd = cmd:gsub("%%", vim.fn.expand("%:t"))
    cmd = cmd:gsub("$file", vim.fn.expand("%:t"))
    cmd = cmd:gsub("$ext", vim.fn.expand("%:e"))
    cmd = cmd:gsub("$basename", vim.fn.expand("%:t:r"))
    cmd = cmd:gsub("$path", vim.fn.expand("%:p"))
    cmd = cmd:gsub("$dir", vim.fn.expand("%:p:h"))
    return cmd
end

function M.build(opts)
    opts = opts or {}

    -- before building
    if config.autosave then
        vim.cmd("silent write")
    end

    -- handle internal commands
    local filetype = vim.bo.filetype
    local cmd = config.commands[filetype]
    local is_internal = config.enable_internals and vim.tbl_contains({ "lua", "vim" }, filetype)
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
    -- TODO: update size on vim resize (probably with autocommand)
    local size = opts.size or config.size

    -- build/run the buffer
    vim.cmd(position .. " " .. size .. "new | term " .. cmd)

    -- configure created buffer
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
    if not config.line_no then
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
    end
end

return M
