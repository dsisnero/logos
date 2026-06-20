.PHONY: install update format lint test markdown markdown-check clean

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
	CRYSTAL_PATH=$$(if [ -d ../regex-automata/src ]; then printf "../regex-automata/src:%s" "$${CRYSTAL_PATH:-$$(crystal env CRYSTAL_PATH)}"; else printf "%s" "$${CRYSTAL_PATH:-$$(crystal env CRYSTAL_PATH)}"; fi) crystal spec

markdown:
	rumdl fmt .

markdown-check:
	rumdl check . --check

clean:
	rm -rf ./temp
