test:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests {minimal_init = 'tests//minimal_init.lua', sequential = true}"

# lint:
# 	selene --config selene/config.toml lua
# 	typos

# lint-short:
# 	selene --config selene/config.toml --display-style Quiet lua

.PHONY: test
