# K8Dev - Kubernetes Local Development Environment Manager

![MIT License](https://img.shields.io/badge/license-MIT-green)

**k8dev** lets you run and manage multiple local web development projects—like WordPress, Laravel, or Node.js apps—on your own computer using Kubernetes (with Rancher Desktop). Each project gets its own isolated environment, custom domain (e.g., `www.example.dev`), and can use different versions of PHP, Node.js, and databases. This makes it easy to develop, test, and debug modern web applications in a setup that closely matches production.

---

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Requirements](#requirements)
- [Security Notice](#security-notice)
- [Installation](#installation)
- [Getting Started](#getting-started)
- [Directory Structure](#directory-structure)
- [Usage Guide](#usage-guide)
  - [Essential Commands](#essential-commands)
  - [Host Management](#host-management)
  - [Accessing Your Projects](#accessing-your-projects)
- [Project Configuration](#project-configuration)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)
- [Known Issues](#known-issues)
- [Contributing](#contributing)
- [Uninstalling k8dev](#uninstalling-k8dev)
- [License](#license)

---

## Introduction

k8dev is a tool that simplifies the management of local development environments using Kubernetes. It allows developers to create, manage, and delete isolated environments for their web projects with ease. Each environment can have its own configuration, including the choice of PHP or Node.js version, database type, and more.

## Features

- Multiple PHP/Node.js environments
- Automatic SSL certificate management
- Built-in MySQL/MariaDB support
- Persistent data storage
- Easy host management
- Custom Docker image support
- Development-friendly debugging tools

## Requirements

- macOS or Linux operating system
- Rancher Desktop 1.9.0 or later
- Helm v3.12.0 or later
- kubectl (installed with Rancher Desktop)
- At least 8GB RAM recommended
- 20GB free disk space

## Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/Nazariy/k8dev.git
    cd k8dev
    ```

2. Install the k8dev command:

    ```bash
    make install
    ```

3. Verify the installation:

    ```bash
    make check
    ```

## Getting Started

To get started with k8dev, follow these steps:

1. Install the base infrastructure:

    ```bash
    k8dev install
    ```

2. Create a new host configuration for your project:

    ```bash
    k8dev create www.example.dev
    ```

3. Start the host:

    ```bash
    k8dev start www.example.dev
    ```

4. Access your project at `https://www.example.dev`

## Directory Structure

The directory structure for a typical k8dev project looks like this:

```graph
k8dev/
├── k8dev/               # Helm chart for infrastructure and per-host deployments
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       └── services/    # Service templates (php, mysql, redis, etc.)
├── docker/              # Dockerfile templates for supported runtimes
│   ├── php/
│   │   ├── 8.2/
│   │   ├── 8.3/
│   │   └── 8.4/
│   └── node/
│       └── 18/
├── hosts/               # Host configurations (can be symlinked)
│   └── www.example.dev/
│       └── values.yaml
├── www/                 # Source code for each host
│   └── www.example.dev/
│       └── index.php
├── data/                # Persistent data (e.g., mysql storage)
│   └── mysql/
│       └── www-example-dev/
├── scaffold/            # Templates for new hosts
│   └── values.yaml
└── docs/                # Documentation (e.g., database-management.md)
```

## Usage Guide

### Essential Commands

Here are some essential commands to get you started with k8dev:

```bash
# Install base infrastructure
k8dev install

# Create a new host configuration
k8dev create www.example.dev

# Start a host
k8dev start www.example.dev

# List all running hosts
k8dev list

# Stop a host
k8dev stop www.example.dev

# Build a Docker image
k8dev build php 8.2

# Force rebuild a Docker image
k8dev build php 8.2 --no-cache

# Remove infrastructure
k8dev uninstall
```

### Host Management

Managing your hosts is easy with k8dev. Here are some common commands:

```bash
# Add new host
k8dev create www.example.dev

# Restart a specific host
k8dev restart www.example.dev

# Graceful shutdown (saves running hosts)
k8dev shutdown

# Reload infrastructure (restores previously running hosts)
k8dev reload

# Check infrastructure status
k8dev debug
```

### Accessing Your Projects

To access your projects, you can use the following URLs:

- Web Application: `https://www.example.dev`
- Database:
  - External Access: `www.example.dev:3306`
  - Internal Access : `www-example-dev-mysql:3306`
- Adminer: `adminer-www.example.dev` (if enabled)
- Grafana: `grafana-www.example.dev` (if enabled)

### Project Configuration

To configure your project, edit the `values.yaml` file in your host directory. Here are some configuration options:

#### Web Application

```yaml
domain: www.example.dev

php:
  enabled: true
  image: acme-php:8.2-fpm
  volumes:
    - source: /path/to/your/project
      target: /var/www/html

nginx:
  enabled: true
  config:
    locations:
      - path: /
        rules: |
          try_files $uri $uri/ /index.php?$query_string;

debug:
  enabled: false
  xdebug:
    enabled: false

ssl:
  enabled: true
  issuer: letsencrypt-staging
```

#### Database Configuration

```yaml
mysql:
  enabled: true
  database: app_database
  user: developer
  password: secret
  storage:
    size: "5Gi"
```

## Development Workflow

To add a new host:

1. Create host configuration:

    ```bash
    k8dev create www.example.dev
    ```

2. Edit the generated configuration in `hosts/www.example.dev/values.yaml`

3. Build required images (if using custom):

    ```bash
    k8dev build php 8.2
    ```

4. Start the host:

    ```bash
    k8dev start www.example.dev
    ```

## Uninstalling k8dev

To remove k8dev, run the following command:

```bash
make uninstall
```

## Troubleshooting

Common issues and solutions:

1. **Cluster Connection Issues**
   - Ensure Rancher Desktop is running
   - Check cluster connection: `kubectl cluster-info`
   - Verify Helm installation: `helm version`

2. **Storage Issues**
   - Check persistent volumes: `kubectl get pv,pvc -A`
   - Verify storage permissions in Rancher Desktop settings

3. **Network Issues**
   - Check ingress status: `kubectl get ingress -A`
   - Verify DNS resolution for your domains

4. **Performance Issues**
   - Adjust Rancher Desktop resource allocation
   - Check system resources usage

## Known Issues

- MySQL connection might require proper hostname configuration
- Initial SSL certificate generation may take a few minutes
- Xdebug configuration might need adjustment based on IDE

---

## Security Notice

> ⚠️ **Be aware:** Supply chain attacks and malicious packages are a risk in all development environments, regardless of the tools you use. Attackers may publish packages with names similar to popular libraries ("typosquatting") or compromise existing packages in public registries (npm, PyPI, Packagist, Go modules, etc.).
>
> This is a general risk for all developers, not specific to k8dev. Always:
>
> - Review and trust the sources of any third-party code, images, or plugins you use.
> - Be cautious when installing new dependencies, especially from unfamiliar sources.
> - Keep your development tools and dependencies up to date.
> - Consider using security tools such as [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/), [Snyk](https://snyk.io/), or [GitHub's Dependabot](https://docs.github.com/en/code-security/supply-chain-security/keeping-your-dependencies_up_to_date-automatically) to monitor for vulnerabilities.
>
> For more information, see:
>
> - [OWASP Top 10: Software Supply Chain Security](https://owasp.org/www-project-top-ten/)
> - [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
> - [Snyk Open Source Security](https://snyk.io/)
> - [GitHub Supply Chain Security](https://docs.github.com/en/code-security/supply-chain-security)

---

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
