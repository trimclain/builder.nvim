test:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests {minimal_init = 'tests//minimal_init.lua', sequential = true}"

lint:
	luacheck lua/builder

# docgen:
# 	nvim --headless --noplugin -u scripts/minimal_init.vim -c "luafile ./scripts/gendocs.lua" -c 'qa'

.PHONY: test lint
