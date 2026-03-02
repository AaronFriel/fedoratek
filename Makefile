SHELL := /bin/bash

.PHONY: help bootstrap bootstrap-testing bootstrap-stable bootstrap-both rebuild-testing rebuild-stable rebuild-both lint

help:
	@echo "Targets:"
	@echo "  bootstrap        - Create/update stable COPR project/package sources"
	@echo "  bootstrap-testing- Create/update only testing COPR project/package sources"
	@echo "  bootstrap-stable - Alias of bootstrap"
	@echo "  bootstrap-both   - Create/update testing+stable COPR project/package sources"
	@echo "  rebuild-testing  - Trigger testing COPR package rebuilds"
	@echo "  rebuild-stable   - Trigger stable COPR package rebuilds"
	@echo "  rebuild-both     - Trigger both testing and stable COPR rebuilds"
	@echo "  lint             - Basic local script/workflow sanity checks"

bootstrap:
	COPR_BOOTSTRAP_TARGET_PROJECTS=stable ./scripts/copr_bootstrap_projects.sh

bootstrap-testing:
	COPR_BOOTSTRAP_TARGET_PROJECTS=testing ./scripts/copr_bootstrap_projects.sh

bootstrap-stable: bootstrap

bootstrap-both:
	COPR_BOOTSTRAP_TARGET_PROJECTS=both ./scripts/copr_bootstrap_projects.sh

rebuild-testing:
	COPR_TARGET_PROJECTS=testing ./scripts/copr_rebuild_all.sh

rebuild-stable:
	COPR_TARGET_PROJECTS=stable ./scripts/copr_rebuild_all.sh

rebuild-both:
	COPR_TARGET_PROJECTS=both ./scripts/copr_rebuild_all.sh

lint:
	bash -n scripts/*.sh
	@echo "Shell syntax checks passed."
