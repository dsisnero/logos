.PHONY: install update format lint test test-prebuilt test-package markdown markdown-check prebuild clean

# Only docs that are currently clean under rumdl are gated; add files here once
# their existing formatting issues are fixed.
DOCS = docs/development.md docs/resuming.md

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

test-prebuilt:
	crystal spec -Dcodegen_library spec/logos/codegen_priority_spec.cr spec/logos/prebuilt_examples_spec.cr

test-package:
	crystal spec -Dpackage_qualification spec/logos/package_spec.cr

# Generate an ordinary Crystal matcher from a JSON manifest before compiling
# an application. Example:
#   make prebuild MANIFEST=temp/extras.json OUT=temp/generated_token.cr
prebuild:
	@test -n "$(MANIFEST)" || (echo "MANIFEST is required"; exit 1)
	@test -n "$(OUT)" || (echo "OUT is required"; exit 1)
	@mkdir -p "$(dir $(OUT))"
	CRYSTAL_PATH=$$(if [ -d ../regex-automata/src ]; then printf "../regex-automata/src:%s" "$${CRYSTAL_PATH:-$$(crystal env CRYSTAL_PATH)}"; else printf "%s" "$${CRYSTAL_PATH:-$$(crystal env CRYSTAL_PATH)}"; fi) crystal run src/logos_codegen.cr -- --manifest "$(MANIFEST)" --out "$(OUT)"

markdown:
	rumdl fmt $(DOCS)

markdown-check:
	rumdl check $(DOCS) --check

clean:
	rm -rf ./temp
