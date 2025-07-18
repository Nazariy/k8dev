# Copilot Instructions for k8dev

## Project Overview

- **k8dev** is a Bash/Helm-based tool for managing multiple local web development environments on Kubernetes (primarily Rancher Desktop).
- Each project/host is defined by its own config in `hosts/<domain>/values.yaml` and is deployed as a Helm release.
- The system supports multiple PHP/Node.js versions, databases, and custom Docker images, with automatic SSL via cert-manager and ingress-nginx.

## Architecture & Key Components

- `k8dev.sh`: Main CLI script. Handles host creation, management, infrastructure install/uninstall, and wraps Helm/Kubectl commands.
- `k8dev/`: Helm chart for infrastructure and per-host deployments. Contains templates for services (php, nginx, mysql, redis, etc.) and ingress.
- `docker/`: Dockerfile templates for supported runtimes (PHP, Node.js).
- `hosts/`: Each subdirectory is a project/host, with its own `values.yaml` for configuration.
- `www/`: Source code for each host, mapped into containers.
- `scaffold/`: Template configs for new hosts.

## Developer Workflows

- **Install CLI:** `make install` (symlinks `k8dev.sh` to `/usr/local/bin/k8dev`)
- **Create Host:** `k8dev create <domain>`
- **Start/Stop Host:** `k8dev start <domain>`, `k8dev stop <domain>`
- **List Hosts:** `k8dev list`
- **Build Images:** `k8dev build php 8.2`
- **Infrastructure:** `k8dev install` (sets up system-wide services), `k8dev uninstall` (removes all)
- **CI:** See `.github/workflows/makefile.yml` for k3d-based test cluster setup.

## Project-Specific Patterns

- **Config-Driven:** All host/service configuration is in YAML files under `hosts/`.
- **Per-Host Isolation:** Each host is a separate Helm release, optionally in its own namespace (future-proof for grouping).
- **Ingress:** Each host gets its own ingress, with SSL enabled via cert-manager and Let's Encrypt.
- **Service Templates:** Helm templates in `k8dev/templates/services/` are parameterized for each host.
- **Custom Images:** Built via `k8dev build` and referenced in host configs.

## Conventions

- **Domain Naming:** Host/project directories and domains must match (e.g., `hosts/www.example.dev/` for `www.example.dev`).
- **Volume Mounts:** Source code is mounted from `www/<domain>/` into containers.
- **Secrets/Passwords:** Set in `values.yaml` per host; not managed globally.
- **/etc/hosts:** User is responsible for mapping domains to `127.0.0.1` (may be automated in future).

## Integration Points

- **Kubernetes:** All deployments, services, and ingress are managed via Helm.
- **Helm Dependencies:** Uses `cert-manager`, `ingress-nginx`, and optionally `loki-stack` (see `Chart.yaml`).
- **Docker:** Used for building custom PHP/Node.js images.
- **CI:** Uses k3d for test clusters in GitHub Actions.

## Host Directory Location

- By default, the `hosts/` directory is located within the project root, but in practice, host configs may be stored elsewhere on the user's machine.
- Symlinks can be used to map external host config directories into the project if desired.
- AI agents should not assume `hosts/` is always local—always resolve symlinks and support custom host config paths if extending tooling.

## Examples

- To add a new PHP project:
  1. `k8dev create mysite.dev`
  2. Edit `hosts/mysite.dev/values.yaml` for PHP version, DB, etc.
  3. Place code in `www/mysite.dev/`
  4. `k8dev start mysite.dev`

- To add a new service (e.g., Redis), enable it in the host's `values.yaml` and ensure a template exists in `k8dev/templates/services/`.

---

**If you need to update these instructions, review `README.md`, `k8dev.sh`, and the Helm chart for current conventions.**
