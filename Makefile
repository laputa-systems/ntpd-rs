.PHONY: lint

lint:
	cargo clippy --workspace --all-targets -- --deny warnings
