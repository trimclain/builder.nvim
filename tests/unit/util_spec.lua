---@diagnostic disable: undefined-field

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
    it("validates them correctly", function()
        assert.are.same(require("builder.util").validate_opts({}), {})
        assert.False(require("builder.util").validate_opts({ missing = true }))

        assert.are.same(require("builder.util").validate_opts({ color = true }), { color = true })
        assert.are.same(require("builder.util").validate_opts({ color = "false" }), { color = false })
        assert.False(require("builder.util").validate_opts({ color = "falser" }))

        assert.are.same(require("builder.util").validate_opts({ alt = "true" }), { alt = true })
        assert.are.same(require("builder.util").validate_opts({ alt = false }), { alt = false })
        assert.False(require("builder.util").validate_opts({ alt = "" }))

        assert.are.same(require("builder.util").validate_opts({ type = "bot" }), { type = "bot" })
        assert.False(require("builder.util").validate_opts({ type = "vertical" }))

        assert.are.same(require("builder.util").validate_opts({ size = 0.25 }), { size = 0.25 })
        assert.are.same(require("builder.util").validate_opts({ size = "0.5" }), { size = 0.5 })
        assert.False(require("builder.util").validate_opts({ size = "-6" }))
        assert.False(require("builder.util").validate_opts({ size = "9" }))

        assert.are.same(
            require("builder.util").validate_opts({ size = "0.2", type = "float", color = "false", alt = "false" }),
            { size = 0.2, type = "float", color = false, alt = false }
        )
    end)
end)

describe("util.calculate_float_dimensions", function()
    it("calculates them correctly", function()
        assert.are.same(
            require("builder.util").calculate_float_dimensions({ height = 0.8, width = 0.8 }),
            { col = 8, height = 15, row = 4, width = 64 }
        )
        assert.are.same(
            require("builder.util").calculate_float_dimensions({ height = 0.3, width = 0.5 }),
            { col = 20, height = 3, row = 10, width = 40 }
        )
    end)
end)

describe("util.calulate_win_size", function()
    it("calculates it correctly", function()
        assert.are.same(require("builder.util").calulate_win_size("bot", 0.5), 12)
        assert.are.same(require("builder.util").calulate_win_size("top", 0.5), 12)
        assert.are.same(require("builder.util").calulate_win_size("vert", 0.5), 40)
    end)
end)
