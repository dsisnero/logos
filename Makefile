.PHONY: install update format lint test markdown markdown-check prebuild clean

install:
	BEADS_DIR=$$(pwd)/.beads shards install

update:
	BEADS_DIR=$$(pwd)/.beads shards update

format:
	crystal tool format --check src spec examples benchmarks

lint:
	ameba --fix
	ameba

test:
	crystal spec

# Generate an ordinary Crystal matcher from a JSON manifest before compiling
# an application. Example:
#   make prebuild MANIFEST=examples/extras.logos.json OUT=temp/generated_token.cr
prebuild:
	@test -n "$(MANIFEST)" || (echo "MANIFEST is required"; exit 1)
	@test -n "$(OUT)" || (echo "OUT is required"; exit 1)
	@mkdir -p "$(dir $(OUT))"
	CRYSTAL_PATH=$$(if [ -d ../regex-automata/src ]; then printf "../regex-automata/src:%s" "$${CRYSTAL_PATH:-$$(crystal env CRYSTAL_PATH)}"; else printf "%s" "$${CRYSTAL_PATH:-$$(crystal env CRYSTAL_PATH)}"; fi) crystal run src/logos_codegen.cr -- --manifest "$(MANIFEST)" --out "$(OUT)"

markdown:
	rumdl fmt docs/development.md

markdown-check:
	rumdl check docs/development.md --check

clean:
	rm -rf ./temp
