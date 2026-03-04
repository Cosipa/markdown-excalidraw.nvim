.PHONY: test test-python test-lua

test: test-python test-lua

test-python:
	python3 -m unittest tests/python/test_server.py -v

test-lua:
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/lua"
