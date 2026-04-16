# ===============================
# CONFIG
# ===============================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ===============================
# HELP
# ===============================

help:
	@echo ""
	@echo "Available commands:"
	@echo "  make build        - Constrói containersbackend/frontend"
	@echo "  make buildb       - Constrói container backend --no-cache"
	@echo "  make buildf       - Constrói container frontend"
	@echo "  make devup        - Inicia containers"
	@echo "  make devdown      - Para containers"
	@echo "  make devrestart   - Restart containers"
	@echo ""

# ===============================
# DOCKER
# ===============================

build:
	@./scripts/build.sh $(v)

buildb:
	@./scripts/build-back.sh $(v)

buildf:
	@./scripts/build-front.sh $(v)

devup:
	@./scripts/dev-up.sh

devdown:
	@./scripts/dev-down.sh

devres: devdown devup

push:
	@./scripts/push.sh $(v)

# ===============================
# LARAVEL
# ===============================

# migrate:
# 	@./scripts/migrate.sh

# test:
# 	@./scripts/test.sh
