.PHONY: install update format lint test markdown markdown-check

install:
	BEADS_DIR=$$(pwd)/.beads shards install

update:
	BEADS_DIR=$$(pwd)/.beads shards update

format:
	crystal tool format --check

lint:
	ameba --fix
	ameba

test:
	crystal spec

markdown:
	rumdl fmt .

markdown-check:
	rumdl check . --check