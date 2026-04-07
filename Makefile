.PHONY: test check integration-test

nim.cfg: nimby.lock
	nimby sync -g nimby.lock

check: nim.cfg
	nim check src/mosty.nim

test: nim.cfg
	@files=$$(ls tests/test_*.nim 2>/dev/null); \
	if [ -z "$$files" ]; then \
		echo "No unit tests found in tests/test_*.nim"; \
		exit 0; \
	fi; \
	fail=0; \
	for f in $$files; do \
		nim r --hints:off --warnings:off "$$f" || fail=1; \
	done; \
	exit $$fail

integration-test: nim.cfg
	@files=$$(ls tests/manual_*.nim 2>/dev/null); \
	if [ -z "$$files" ]; then \
		echo "No integration tests found in tests/manual_*.nim"; \
		exit 0; \
	fi; \
	fail=0; \
	for f in $$files; do \
		nim r --hints:off --warnings:off "$$f" || fail=1; \
	done; \
	exit $$fail
