SHELL := /bin/bash
CURRENT_DIR := $(shell pwd)
INSTALL_PATH := /usr/local/bin/k8dev

.PHONY: install uninstall check test help

help:
	@echo "Available commands:"
	@echo "  make install     - Install k8dev command"
	@echo "  make uninstall   - Remove k8dev command"
	@echo "  make check       - Check installation status"
	@echo "  make test        - Run tests"

install:
	@echo "Installing k8dev..."
	@if [ ! -f $(CURRENT_DIR)/k8dev.sh ]; then \
		echo "Error: k8dev.sh not found in current directory"; \
		exit 1; \
	fi
	@chmod +x $(CURRENT_DIR)/k8dev.sh
	@if [ -f $(INSTALL_PATH) ]; then \
		sudo rm -f $(INSTALL_PATH); \
	fi
	@sudo ln -sf $(CURRENT_DIR)/k8dev.sh $(INSTALL_PATH)
	@echo "k8dev installed successfully!"
	@echo "Try 'k8dev help' to get started"

uninstall:
	@echo "Uninstalling k8dev..."
	@if [ -f $(INSTALL_PATH) ]; then \
		sudo rm -f $(INSTALL_PATH); \
		echo "k8dev uninstalled successfully!"; \
	else \
		echo "k8dev is not installed"; \
	fi

check:
	@echo "Checking k8dev installation..."
	@if [ -L $(INSTALL_PATH) ]; then \
		echo "Installation path: $(shell readlink -f $(INSTALL_PATH))"; \
		echo "Version: $$(k8dev version 2>/dev/null || echo 'unknown')"; \
		kubectl version --client || echo "kubectl not found"; \
		helm version --client || echo "helm not found"; \
	else \
		echo "k8dev is not installed"; \
	fi

test:
	@echo "Running tests..."
	@echo "Checking script syntax..."
	@bash -n k8dev.sh || exit 1
	@echo "Checking for required commands..."
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "helm not found"; exit 1; }