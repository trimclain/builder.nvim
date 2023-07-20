local M = {}

local config = {
    terminal = {
        position = "bot",
        line_no = false,
        size = 10,
    },
}

function M.setup(opts)
    opts = vim.tbl_deep_extend("force", config, opts or {})
end

-- local function dimensions(opts)
--     local cl = vim.o.columns
--     local ln = vim.o.lines
--     local width = math.ceil(cl * opts.ui.float.width)
--     local height = math.ceil(ln * opts.ui.float.height - 4)
--     local col = math.ceil((cl - width) * opts.ui.float.x)
--     local row = math.ceil((ln - height) * opts.ui.float.y - 1)
--     return {
--         width = width,
--         height = height,
--         col = col,
--         row = row,
--     }
-- end

-- local function resize()
--     local dim = dimensions(config)
--     vim.api.nvim_win_set_config(M.win, {
--         style = "minimal",
--         relative = "editor",
--         border = config.ui.float.border,
--         height = dim.height,
--         width = dim.width,
--         col = dim.col,
--         row = dim.row,
--     })
-- end

-- local function substitute(cmd)
--     cmd = cmd:gsub("%%", vim.fn.expand("%"))
--     cmd = cmd:gsub("$fileBase", vim.fn.expand("%:r"))
--     cmd = cmd:gsub("$filePath", vim.fn.expand("%:p"))
--     cmd = cmd:gsub("$file", vim.fn.expand("%"))
--     cmd = cmd:gsub("$dir", vim.fn.expand("%:p:h"))
--     cmd = cmd:gsub(
--         "$moduleName",
--         vim.fn.substitute(
--             vim.fn.substitute(vim.fn.fnamemodify(vim.fn.expand("%:r"), ":~:."), "/", ".", "g"),
--             "\\",
--             ".",
--             "g"
--         )
--     )
--     cmd = cmd:gsub("#", vim.fn.expand("#"))
--     cmd = cmd:gsub("$altFile", vim.fn.expand("#"))
--     return cmd
-- end

local function term(cmd)
    vim.cmd(config.terminal.position .. " " .. config.terminal.size .. "new | term " .. cmd)

    local buf = vim.api.nvim_get_current_buf()

    vim.bo[buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
    -- vim.keymap.set("n", "<ESC>", "<cmd>close<cr>", { buffer = buf, silent = true })
    -- vim.api.nvim_buf_set_keymap(buf, "n", "<ESC>", "<cmd>:bdelete!<CR>", { silent = true })

    -- if not config.ui.terminal.line_no then
    --     vim.cmd("setlocal nonumber | setlocal norelativenumber")
    -- end
end

local function run(cmd)
    cmd = cmd or config.cmds.external[vim.bo.filetype]

    if not cmd then
        vim.cmd("echohl ErrorMsg | echo 'Error: Invalid command' | echohl None")
        return
    end

    -- if config.behavior.autosave then
    --     vim.cmd("silent write")
    -- end

    -- cmd = substitute(cmd)
    -- if type == "terminal" then
    term(cmd)
    -- end

    -- vim.cmd("echohl ErrorMsg | echo 'Error: Invalid type' | echohl None")
end

function M.Build(cmd)
    -- local file = io.open(vim.fn.expand("%:p:h") .. "/.jaq.json", "r")

    -- -- Check if the filetype is in config.cmds.internal
    -- if vim.tbl_contains(vim.tbl_keys(config.cmds.internal), vim.bo.filetype) then
    --     -- Exit if the type was passed and isn't "internal"
    --     if type and type ~= "internal" then
    --         vim.cmd("echohl ErrorMsg | echo 'Error: Invalid type for internal command' | echohl None")
    --         return
    --     end
    --     type = "internal"
    -- else
    --     type = type or config.behavior.default
    -- end

    -- if type == "internal" then
    --     internal()
    --     return
    -- end

    run(cmd)
end

return M
