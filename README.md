# K8Dev - Kubernetes Local Development Environment Manager

![MIT License](https://img.shields.io/badge/license-MIT-green)

**K8Dev** is a tool for managing multiple local development environments using Kubernetes (Rancher Desktop).
It allows you to run different projects with various PHP versions and configurations simultaneously.

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

## Quick Start

```bash
git clone https://github.com/Nazariy/k8dev.git
cd k8dev
make install
k8dev install
k8dev create example.dev
k8dev start example.dev
```

## Usage

### Basic Commands

```bash
# Install base infrastructure
k8dev install

# Create a new host configuration
k8dev create example.dev

# Start a host
k8dev start example.dev

# List all running hosts
k8dev list

# Stop a host
k8dev stop example.dev

# Build a Docker image
k8dev build php 8.2

# Force rebuild a Docker image
k8dev build php 8.2 --no-cache

# Remove infrastructure
k8dev uninstall
```

### Common Operations

#### Managing Hosts
```bash
# Add new host
k8dev create example.dev

# Restart a specific host
k8dev restart example.dev

# Graceful shutdown (saves running hosts)
k8dev shutdown

# Reload infrastructure (restores previously running hosts)
k8dev reload

# Check infrastructure status
k8dev debug
```

### Accessing Services

To add new domain to your local environment for example `www.domain.dev` use this command:
```bash
k8dev create www.domain.dev
```


- Web Application: https://www.domain.dev
- Database:
  - External Access: `www.domain.dev:3306`
  - Internal Access : `www-domain-dev-mysql:3306`
- Adminer: `adminer-www.domain.dev` (if enabled)
- Grafana: `grafana-www.domain.dev` (if enabled)

### Project Structure

```
k8dev/
├── k8dev/               # Helm chart for infrastructure
├── docker/              # Dockerfile templates
│   ├── php/
│   │   ├── 7.4/
│   │   ├── 8.1/
│   │   └── 8.2/
│   └── node/
│       ├── 16/
│       └── 18/
├── hosts/               # Host configurations
│   └── www.domain.dev/
│       └── values.yaml
├── www/                 # Source files
│   └── www.domain.dev/
│       └── index.php
└── scaffold/            # Templates for new hosts
    └── values.yaml
```

### Configuration

Edit the `values.yaml` in your host directory to configure various services:

#### Web Application
```yaml
domain: www.domain.dev

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

## Development

To add a new host:

1. Create host configuration:
    ```bash
    k8dev create your.domain.dev
    ```

2. Edit the generated configuration in `hosts/www.domain.dev/values.yaml`

3. Build required images (if using custom):
    ```bash
    k8dev build php 8.2
    ```

4. Start the host:
    ```bash
    k8dev start www.domain.dev
    ```

## Make Commands

```bash
# Install k8dev command
make install

# Remove k8dev command
make uninstall

# Check installation status
make check

# Show available make commands
make help
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

## Contributing
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Create a Pull Request

## Uninstallation

To remove k8dev:
```bash
make uninstall
```

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
