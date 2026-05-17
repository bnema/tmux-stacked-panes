SHELL := /usr/bin/env bash

TESTS := $(filter-out tests/helpers.sh,$(sort $(wildcard tests/*.sh)))

.PHONY: test

test:
	@set -euo pipefail; \
	for test_script in $(TESTS); do \
		echo "==> $$test_script"; \
		bash "$$test_script"; \
	done
