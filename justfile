# Build the docs site.
# Requires: mdbook, mdbook-mermaid, mdbook-d2, and the d2 CLI on PATH.
# Install via: cargo install --locked mdbook mdbook-mermaid mdbook-d2
# d2 CLI: https://d2lang.com/tour/install
docs:
    mdbook build docs/

# Serve the docs site locally with live reload.
docs-serve:
    mdbook serve docs/

# Generate docs/_published/llms.txt + docs/_published/llms-full.txt from docs/_published/agent/.
# Requires: uv on PATH.
docs-llms:
    uv run scripts/docs-llms.py

# Run both docs drift gates (translate + llms).
docs-check:
    uv run scripts/docs-translate.py --check
    uv run scripts/docs-llms.py --check

# Full gate: docs build + docs-translate --check + docs-llms --check.
check:
    mdbook build docs/
    uv run scripts/docs-translate.py --check --src docs/src --out docs/_published --prompts docs/prompts
    uv run scripts/docs-llms.py --check
