describe("builder", function()
    local builder = require("builder")
    local dir
    local source_file_buf
    local build_win

    before_each(function()
        dir = vim.fn.tempname() .. " builder test"
        assert.are.equal(1, vim.fn.mkdir(dir, "p"))

        builder.setup({
            type = "bot",
            autosave = false,
            measure_time = false,
            commands = {
                sh = "bash $path",
                python = "python3 $path",
            },
        })
    end)

    after_each(function()
        if build_win and vim.api.nvim_win_is_valid(build_win) then
            vim.api.nvim_win_close(build_win, true)
        end
        build_win = nil

        if source_file_buf and vim.api.nvim_buf_is_valid(source_file_buf) then
            vim.api.nvim_buf_delete(source_file_buf, { force = true })
        end
        source_file_buf = nil

        if dir then
            vim.fn.delete(dir, "rf")
        end
    end)

    it("builds a bash file whose path contains spaces using builder lua module", function()
        assert.are.equal(1, vim.fn.executable("bash"))

        local file = dir .. "/hello world.sh"
        assert.are.equal(0, vim.fn.writefile({ 'echo "hello from bash"' }, file))

        vim.cmd.edit(vim.fn.fnameescape(file))
        source_file_buf = vim.api.nvim_get_current_buf()
        builder.build({})

        build_win = vim.api.nvim_get_current_win()
        assert.are.same({ "hello from bash" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("builds a python file whose path contains spaces using builder user command", function()
        assert.are.equal(1, vim.fn.executable("python3"))

        local file = dir .. "/hello-world.py"
        assert.are.equal(0, vim.fn.writefile({ 'print("hello from python")' }, file))

        vim.cmd.edit(vim.fn.fnameescape(file))
        vim.cmd("Build")

        build_win = vim.api.nvim_get_current_win()
        assert.are.same({ "hello from python" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    -- it("does not try to build an unconfigured filetype", function()
    --     local file = dir .. "/hello-world.rb"
    --     assert.are.equal(0, vim.fn.writefile({ 'puts "hello from ruby"' }, file))

    --     vim.cmd.edit(vim.fn.fnameescape(file))
    --     vim.cmd("Build")

    --     build_win = vim.api.nvim_get_current_win()
    --     assert.are.same({ "hello from python" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    -- end)
end)

describe("builder", function()
    local builder = require("builder")
    local util = require("builder.util")
    local original_info

    before_each(function()
        original_info = util.info

        builder.setup({
            autosave = false,
            commands = {},
        })

        vim.bo.filetype = "ruby"
    end)

    after_each(function()
        util.info = original_info
    end)

    it("reports when the current filetype has no configured build command", function()
        local message

        ---@diagnostic disable-next-line: duplicate-set-field
        util.info = function(msg)
            message = msg
        end

        builder.build({})

        assert.are.equal('Building "ruby" is not configured', message)
    end)
end)
