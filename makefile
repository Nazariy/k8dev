SHELL := /bin/bash
CURRENT_DIR := $(shell pwd)
INSTALL_PATH := /usr/local/bin/k8dev

.PHONY: install uninstall check help

help:
	@echo "Available commands:"
	@echo "  make install      - Install k8dev command"
	@echo "  make uninstall   - Remove k8dev command"
	@echo "  make check       - Check installation status"

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
	else \
		echo "k8dev is not installed"; \
	fi