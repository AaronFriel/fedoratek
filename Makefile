SHELL := /bin/bash

.PHONY: help bootstrap rebuild-testing rebuild-stable rebuild-both lint

help:
	@echo "Targets:"
	@echo "  bootstrap        - Create/update COPR projects and package sources"
	@echo "  rebuild-testing  - Trigger testing COPR package rebuilds"
	@echo "  rebuild-stable   - Trigger stable COPR package rebuilds"
	@echo "  rebuild-both     - Trigger both testing and stable COPR rebuilds"
	@echo "  lint             - Basic local script/workflow sanity checks"

bootstrap:
	./scripts/copr_bootstrap_projects.sh

rebuild-testing:
	COPR_TARGET_PROJECTS=testing ./scripts/copr_rebuild_all.sh

rebuild-stable:
	COPR_TARGET_PROJECTS=stable ./scripts/copr_rebuild_all.sh

rebuild-both:
	COPR_TARGET_PROJECTS=both ./scripts/copr_rebuild_all.sh

lint:
	bash -n scripts/*.sh
	@echo "Shell syntax checks passed."
