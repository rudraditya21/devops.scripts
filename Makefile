SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

BASH_FILES_CMD = find . -type f \( -name "*.sh" -o -name "*.bash" \) \
	! -path "./.git/*" \
	! -path "./.venv/*" \
	! -path "./site/*"

MKDOCS := .venv/bin/mkdocs

.PHONY: help tools docs-install docs-serve docs-build format format-check lint check bash-format bash-format-check bash-lint

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "%-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

tools: ## Validate required local tooling
	@command -v python3 >/dev/null || { echo "python3 is required."; exit 1; }
	@command -v shfmt >/dev/null || { echo "shfmt is required. Install it via brew or apt."; exit 1; }
	@command -v shellcheck >/dev/null || { echo "shellcheck is required. Install it via brew or apt."; exit 1; }

docs-install: ## Create local venv and install documentation dependencies
	python3 -m venv .venv
	.venv/bin/python -m pip install --upgrade pip
	.venv/bin/pip install -r requirements-docs.txt

docs-serve: ## Serve docs locally at http://127.0.0.1:8000
	@test -x "$(MKDOCS)" || { echo "MkDocs is not installed. Run: make docs-install"; exit 1; }
	$(MKDOCS) serve -a 127.0.0.1:8000

docs-build: ## Build docs in strict mode
	@test -x "$(MKDOCS)" || { echo "MkDocs is not installed. Run: make docs-install"; exit 1; }
	$(MKDOCS) build --strict

bash-format: ## Format all Bash scripts with shfmt
	@count="$$( $(BASH_FILES_CMD) | wc -l | tr -d ' ' )"; \
	if [ "$$count" -eq 0 ]; then \
		echo "No Bash files found."; \
		exit 0; \
	fi
	@$(BASH_FILES_CMD) -print0 | xargs -0 shfmt -w -i 2 -ci -sr

bash-format-check: ## Check Bash formatting without modifying files
	@count="$$( $(BASH_FILES_CMD) | wc -l | tr -d ' ' )"; \
	if [ "$$count" -eq 0 ]; then \
		echo "No Bash files found."; \
		exit 0; \
	fi
	@$(BASH_FILES_CMD) -print0 | xargs -0 shfmt -d -i 2 -ci -sr

bash-lint: ## Lint Bash scripts with shellcheck
	@count="$$( $(BASH_FILES_CMD) | wc -l | tr -d ' ' )"; \
	if [ "$$count" -eq 0 ]; then \
		echo "No Bash files found."; \
		exit 0; \
	fi
	@$(BASH_FILES_CMD) -print0 | xargs -0 shellcheck -x

format: bash-format ## Run all formatters

format-check: bash-format-check ## Verify formatting without changing files

lint: bash-lint ## Run linters

check: tools format-check lint docs-build ## Run full local quality gate
