describe("builder", function()
    it("can be required correctly", function()
        require("builder")
    end)
end)

-- TODO: can I create tests covering following stuff:
-- - [ ] :Build command
-- - [ ] :Build command with arguments
-- - [ ] :Build command with invalid arguments
-- - [ ] :Build command with invalid options
-- - [ ] :Build command with invalid type
-- - [ ] :Build command with invalid color
-- - [ ] :Build command with invalid size
-- - [ ] :Build command with invalid command
-- - [ ] :Build command with invalid command and filetype
-- - [ ] run_command
-- - [ ] legacy_run_command
-- - [ ] run_in_term
-- - [ ] create_buffer
