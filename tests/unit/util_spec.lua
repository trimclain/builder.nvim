describe("util.parse", function()
    local parse = require("builder.util").parse

    it("parses valid arguments", function()
        assert.are.same({ color = "true", type = "vert" }, parse("color=true type=vert"))
        assert.are.same({}, parse(""))
        assert.are.same({}, parse("   "))
    end)

    it("rejects arguments without a nonempty key and value", function()
        assert.is_nil(parse("asd"))
        assert.is_nil(parse("type="))
        assert.is_nil(parse("=true"))
        assert.is_nil(parse("color=true type="))
        assert.is_nil(parse("=truetype="))
    end)
end)

describe("util.validate_opts", function()
    local validate_opts = require("builder.util").validate_opts

    it("accepts empty or omitted options", function()
        assert.are.same({}, validate_opts({}))
        assert.are.same({}, validate_opts(nil))
    end)

    it("rejects unknown options", function()
        assert.is_false(validate_opts({ missing = true }))
    end)

    it("accepts and converts color", function()
        assert.are.same({ color = true }, validate_opts({ color = true }))
        assert.are.same({ color = false }, validate_opts({ color = false }))
        assert.are.same({ color = true }, validate_opts({ color = "true" }))
        assert.are.same({ color = false }, validate_opts({ color = "false" }))
    end)

    it("rejects invalid color values", function()
        assert.is_false(validate_opts({ color = "off" }))
        assert.is_false(validate_opts({ color = "" }))
    end)

    it("accepts and converts alt", function()
        assert.are.same({ alt = true }, validate_opts({ alt = true }))
        assert.are.same({ alt = false }, validate_opts({ alt = false }))
        assert.are.same({ alt = true }, validate_opts({ alt = "true" }))
        assert.are.same({ alt = false }, validate_opts({ alt = "false" }))
    end)

    it("rejects invalid alt values", function()
        assert.is_false(validate_opts({ alt = "maybe" }))
        assert.is_false(validate_opts({ alt = "" }))
    end)

    it("accepts supported window types", function()
        for _, window_type in ipairs({ "bot", "top", "vert", "float" }) do
            assert.are.same({ type = window_type }, validate_opts({ type = window_type }))
        end
    end)

    it("rejects unsupported window types", function()
        assert.is_false(validate_opts({ type = "vertical" }))
        assert.is_false(validate_opts({ type = "" }))
    end)

    it("accepts and converts sizes in (0, 1]", function()
        assert.are.same({ size = 0.25 }, validate_opts({ size = 0.25 }))
        assert.are.same({ size = 0.5 }, validate_opts({ size = "0.5" }))
        assert.are.same({ size = 1 }, validate_opts({ size = "1" }))
    end)

    it("rejects invalid sizes", function()
        for _, size in ipairs({ "-6", "9", "0", "1.01", "abc", "" }) do
            assert.is_false(validate_opts({ size = size }))
        end
    end)

    it("validates several options together", function()
        assert.are.same(
            {
                size = 0.2,
                type = "float",
                color = false,
                alt = false,
            },
            validate_opts({
                size = "0.2",
                type = "float",
                color = "false",
                alt = "false",
            })
        )
    end)
end)

describe("util.calculate_float_dimensions", function()
    local calculate_float_dimensions = require("builder.util").calculate_float_dimensions
    local original_columns
    local original_lines

    before_each(function()
        original_columns = vim.o.columns
        original_lines = vim.o.lines

        vim.o.columns = 80
        vim.o.lines = 24
    end)

    after_each(function()
        vim.o.columns = original_columns
        vim.o.lines = original_lines
    end)

    it("calculates dimensions for an 80% float", function()
        assert.are.same(
            { width = 64, height = 15, row = 4, col = 8 },
            calculate_float_dimensions({ width = 0.8, height = 0.8 })
        )
    end)

    it("calculates dimensions for a non-square float", function()
        assert.are.same(
            { width = 40, height = 3, row = 10, col = 20 },
            calculate_float_dimensions({ width = 0.5, height = 0.3 })
        )
    end)

    it("rounds dimensions up to whole cells", function()
        assert.are.same(
            { width = 27, height = 11, row = 6, col = 27 },
            calculate_float_dimensions({ width = 0.33, height = 0.66 })
        )
    end)
end)

describe("util.calulate_win_size", function()
    local calulate_win_size = require("builder.util").calulate_win_size
    local original_columns
    local original_lines

    before_each(function()
        original_columns = vim.o.columns
        original_lines = vim.o.lines

        vim.o.columns = 80
        vim.o.lines = 24
    end)

    after_each(function()
        vim.o.columns = original_columns
        vim.o.lines = original_lines
    end)

    it("uses editor height for a bottom split", function()
        assert.are.equal(12, calulate_win_size("bot", 0.5))
    end)

    it("uses editor height for a top split", function()
        assert.are.equal(12, calulate_win_size("top", 0.5))
    end)

    it("uses editor width for a vertical split", function()
        assert.are.equal(40, calulate_win_size("vert", 0.5))
    end)

    it("rounds split dimensions down to whole cells", function()
        assert.are.equal(7, calulate_win_size("bot", 0.33))
        assert.are.equal(26, calulate_win_size("vert", 0.33))
    end)
end)
