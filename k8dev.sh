#!/bin/bash

# Set strict error handling
set -euo pipefail

# Variables
VERSION="1.0.0"
NAME="k8dev"
INFRA_RELEASE_NAME="${NAME}-infra"
SYSTEM_NAMESPACE="${NAME}-system"
APPS_NAMESPACE="${NAME}-apps"
# Base directories
PROJECT_ROOT=$(pwd)
CHART_DIR="${PROJECT_ROOT}/${NAME}"

RUNNING_HOSTS_FILE="${CHART_DIR}/.hosts"

export PROJECT_ROOT

output() {
    # Define colors locally within the function
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m' # No Color

    # Check if we have at least one argument
    if [ $# -eq 0 ]; then
        echo -e "${RED}Error: output function requires at least one argument${NC}"
        return 1
    fi

    # If only one argument, treat it as a plain message
    if [ $# -eq 1 ]; then
        echo -e "$1"
        return 0
    fi

    local type="$1"
    local message="$2"

    case "${type}" in
        "error")
            echo -e "${RED}Error: ${message}${NC}"
            exit 1
            ;;
        "warning")
            echo -e "${YELLOW}${message}${NC}"
            ;;
        "success")
            echo -e "${GREEN}${message}${NC}"
            ;;
        "info")
            echo -e "${BLUE}${message}${NC}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac
}

# Function to check requirements
check_requirements() {

    if ! command -v kubectl &> /dev/null; then
        output error "kubectl is not installed"
    fi

    if ! command -v helm &> /dev/null; then
        output error "helm is not installed"
    fi

    if ! kubectl cluster-info &> /dev/null; then
        output error "Unable to connect to Kubernetes cluster"
    fi
}

# Function to convert domain to release name
domain_to_release() {
    local domain=$1
    echo "${domain//[.]/-}"
}

handle_dependencies() {
    local force_update=${1:-false}
    local chart_lock="${CHART_DIR}/Chart.lock"
    local chart_yaml="${CHART_DIR}/Chart.yaml"
    local last_update_mac
    local last_update_linux
    local last_update
    local current_time
    local time_diff

    if [[ -f "${chart_lock}" ]]; then
        last_update_mac=$(stat -f %m "${chart_lock}" 2>/dev/null)
        last_update_linux=$(stat -c %Y "${chart_lock}" 2>/dev/null)
        last_update=${last_update_mac:-$last_update_linux}

        if [[ -n "${last_update}" ]]; then
            current_time=$(date +%s)
            time_diff=$((current_time - last_update))

            if [[ "$force_update" == "true" ]] || [[ $time_diff -gt 86400 ]]; then
                output info "Updating Helm repositories..."
                helm repo update || output error "Failed to update Helm repositories"
            else
                output info "Skipping repository update (less than 24h since last update)"
            fi
        else
            output info "Could not determine Chart.lock timestamp, updating repositories..."
            helm repo update || output error "Failed to update Helm repositories"
        fi
    else
        output info "No Chart.lock found, updating repositories..."
        helm repo update || output error "Failed to update Helm repositories"
    fi

    if [ ! -d "${CHART_DIR}/charts" ] || [ ! -f "${chart_lock}" ]; then
        output info "Initial dependency build required..."
        helm dependency build "${CHART_DIR}" || output error "Failed to build dependencies"
    elif [ "${chart_yaml}" -nt "${chart_lock}" ]; then
        output info "Chart.yaml has been modified, rebuilding dependencies..."
        helm dependency build "${CHART_DIR}" || output error "Failed to build dependencies"
    else
        output info "Dependencies are up to date"
    fi
}

infra_install() {
    output info "🪁 K8dev Starting installation..."

    handle_dependencies true

    # Create required namespaces
    output info "Creating namespaces..."
    kubectl create namespace ${SYSTEM_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace ${APPS_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

    # Apply StorageClass first
    kubectl apply -f ./k8s/storage/local-path-retain.yaml

    # Install the chart
    output info "Installing infrastructure components..."
    helm install "${INFRA_RELEASE_NAME}" "${CHART_DIR}" \
        --namespace ${SYSTEM_NAMESPACE} \
        --timeout 5m || output error "Failed to install infrastructure"

    echo "Checking deployments..."
    kubectl get deployments -A

    # Wait for ingress-nginx to be ready
    echo "Waiting for ingress-nginx deployment..."
    kubectl wait --for=condition=Available deployment/${INFRA_RELEASE_NAME}-ingress-nginx-controller -n ${SYSTEM_NAMESPACE} --timeout=180s || \
        output error "Timeout waiting for ingress-nginx"

    # Wait for cert-manager to be ready
    echo "Waiting for cert-manager deployment..."
    kubectl wait --for=condition=Available deployment/${INFRA_RELEASE_NAME}-cert-manager -n ${SYSTEM_NAMESPACE} --timeout=180s || \
        output error "Timeout waiting for cert-manager"

    output success "Installation completed successfully!"
}

infra_reload() {
    output info "Reloading infrastructure templates..."

    handle_dependencies

    # Check if release exists
    if helm list -A | grep -q "^${INFRA_RELEASE_NAME}"; then
        output info "Updating existing installation: ${INFRA_RELEASE_NAME}"
        helm upgrade "${INFRA_RELEASE_NAME}" "${CHART_DIR}" \
            --namespace "${SYSTEM_NAMESPACE}" || output error "Failed to update infrastructure"
        output success "Infrastructure templates updated successfully"
    else
        output warning "No existing release '${INFRA_RELEASE_NAME}' found"
        output info "Installing fresh..."
        infra_install
    fi

    # Always try to restore hosts
    restore_hosts
}

infra_shutdown() {
    output info "Gracefully shutting down infrastructure..."

    # Save list of running hosts before shutdown
    helm list -n "${APPS_NAMESPACE}" --short > "${RUNNING_HOSTS_FILE}" || \
        output warning "Failed to save running hosts list"

    for namespace in "${APPS_NAMESPACE}" "${SYSTEM_NAMESPACE}"; do
        output info "Scaling down workloads in ${namespace}..."

        # Scale down deployments and stateful sets
        kubectl scale deployment,statefulset --all --replicas=0 -n "${namespace}" || \
            output warning "Failed to scale down some workloads in ${namespace}"

        # Delete DaemonSets (or scale them down if possible)
        kubectl delete daemonset --all -n "${namespace}" || \
            output warning "Failed to remove DaemonSets in ${namespace}"
    done

    output success "Infrastructure successfully shut down"
    output info "To restart, use: ${NAME} reload"
}

infra_uninstall() {
    output warning "⚠️ This will completely remove all infrastructure components and hosts!"
    echo
    output warning "This action will:"
    output warning "  • Remove all running hosts and their configurations"
    output warning "  • Delete all services, deployments, and stateful sets"
    output warning "  • Remove ingress controllers and cert-manager"
    output warning "  • Delete all related namespaces, CRDs, and RBAC resources"
    output warning "  • Clean up all cluster-level resources related to ${NAME}"
    echo
    output warning "Note: This action cannot be undone!"
    echo

    read -r -p "Are you sure you want to proceed? (yes/no): " confirmation

    if [[ "${confirmation}" != "yes" ]]; then
        output info "Uninstallation cancelled"
        return
    fi

    output info "Starting uninstallation process..."

    # Check if release exists before trying operations
    if helm list -n "${SYSTEM_NAMESPACE}" | grep -q "^${INFRA_RELEASE_NAME}"; then
        output info "Removing ClusterIssuers..."
        kubectl delete clusterissuer letsencrypt-staging --ignore-not-found=true
        kubectl delete clusterissuer letsencrypt-prod --ignore-not-found=true

        output info "Removing secrets..."
        kubectl delete secret ${INFRA_RELEASE_NAME}-cert-manager-webhook-ca --ignore-not-found=true
        kubectl delete secret ${INFRA_RELEASE_NAME}-ingress-nginx-admission --ignore-not-found=true

        output info "Removing leases..."
        kubectl delete lease ${INFRA_RELEASE_NAME}-ingress-nginx-leader --ignore-not-found=true

        output info "Uninstalling infrastructure components..."
        helm uninstall "${INFRA_RELEASE_NAME}" -n "${SYSTEM_NAMESPACE}" || true
    else
        output info "No infrastructure release found, skipping Helm uninstall"
    fi

    # These operations should run regardless of release existence
    output info "Removing all hosts..."
    helm list -n "${APPS_NAMESPACE}" --short | xargs -r helm uninstall -n "${APPS_NAMESPACE}"

    output info "Removing apps namespace..."
    kubectl delete namespace "${APPS_NAMESPACE}" --ignore-not-found=true || {
        echo "Force deleting apps namespace..."
        kubectl get namespace ${APPS_NAMESPACE} -o json | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/${APPS_NAMESPACE}/finalize" -f -
    }

    output info "Removing CRDs..."
    kubectl delete crd -l app.kubernetes.io/instance="${INFRA_RELEASE_NAME}" || true
    kubectl delete crd -l app.kubernetes.io/name=cert-manager || true

    output info "Removing system namespace..."
    kubectl delete namespace "${SYSTEM_NAMESPACE}" --ignore-not-found=true || {
        output info "Force deleting system namespace..."
        kubectl get namespace ${SYSTEM_NAMESPACE} -o json | \
        jq '.spec.finalizers = []' | \
        kubectl replace --raw "/api/v1/namespaces/${SYSTEM_NAMESPACE}/finalize" -f -
    }

    output warning "Removing cluster roles and bindings..."
    kubectl delete clusterrole -l app.kubernetes.io/instance="${INFRA_RELEASE_NAME}" || true
    kubectl delete clusterrolebinding -l app.kubernetes.io/instance="${INFRA_RELEASE_NAME}" || true

    output success "Infrastructure and all hosts uninstalled successfully"
}

infra_debug() {
    output info "Starting infrastructure health check..."

    # Function to run command safely
    run_safe() {
        output info "\n$1"
        if ! eval "$2"; then
            output warning "Command failed but continuing..."
        fi
    }

    # Essential health checks
    run_safe "Checking cluster status:" "kubectl cluster-info"
    run_safe "Checking nodes:" "kubectl get nodes -o wide"
    run_safe "Checking system pods:" "kubectl get pods -n ${SYSTEM_NAMESPACE}"
    run_safe "Checking application pods:" "kubectl get pods -n ${APPS_NAMESPACE}"
    run_safe "Checking failed pods:" "kubectl get pods -A --field-selector 'status.phase!=Running,status.phase!=Succeeded'"
    run_safe "Checking ingress status:" "kubectl get ingress -A"
    run_safe "Checking persistent volumes:" "kubectl get pv,pvc -A"

    # Check for recent errors
    run_safe "Recent error events:" "kubectl get events -A --sort-by='.lastTimestamp' | grep -E 'Warning|Error' || true"

    output success "Infrastructure health check completed"
}

# Function to create new host
host_create() {
    local domain=$1
    local hosts_dir="./hosts/${domain}"
    local template_file="./scaffold/values.yaml"

    # Check if host already exists
    if [[ -d "${hosts_dir}" ]]; then
        output error "Host already exists: ${domain}"
    fi

    # Check if template exists
    if [[ ! -f "${template_file}" ]]; then
        output error "Template file not found: ${template_file}"
    fi

    echo "Creating new host for domain: ${domain}"

    # Create host directory
    mkdir -p "${hosts_dir}"

    # Export domain
    export DOMAIN="${domain}"

    # Generate values.yaml from template
    envsubst < "${template_file}" > "${hosts_dir}/values.yaml" || \
        output error "Failed to generate values.yaml"

    # Unset exported variable
    unset DOMAIN

    output success "Host created successfully at: ${hosts_dir}"
    output info "Next steps:"
    echo "1. Edit ${hosts_dir}/values.yaml to configure your host"
    echo "2. Run '${NAME} start ${domain}' to start the host"
}

host_start() {
    local domain=$1
    local release_name
    release_name=$(domain_to_release "${domain}")
    local values_file="./hosts/${domain}/values.yaml"

    # Check if values file exists
    if [[ ! -f "${values_file}" ]]; then
        output error "Host configuration not found: ${values_file}"
    fi

    output info "Starting host: ${domain}"
    helm install "${release_name}" "${CHART_DIR}" \
        --namespace ${APPS_NAMESPACE} \
        -f "${values_file}" \
        --set cert-manager.enabled=false \
        --set ingress-nginx.enabled=false || \
        output error "Failed to start host ${domain}"

    output success "Host ${domain} started successfully"
}

host_stop() {
    local domain=$1
    local release_name
    release_name=$(domain_to_release "${domain}")

    output info "Stopping host: ${domain}"
    helm uninstall "${release_name}" -n "${APPS_NAMESPACE}" || \
        output error "Failed to stop host ${domain}"

    output success "Host ${domain} stopped successfully"
}

host_restart() {
    local domain=$1
    local release_name
    release_name=$(domain_to_release "${domain}")
    local values_file="./hosts/${domain}/values.yaml"

    output info "Restarting host: ${domain}"

    # Check if values file exists
    if [[ ! -f "${values_file}" ]]; then
        output error "Host configuration not found: ${values_file}"
    fi

    # Upgrade/restart the deployment
    helm upgrade "${release_name}" "${CHART_DIR}" \
        --namespace ${APPS_NAMESPACE} \
        -f "${values_file}" \
        --set cert-manager.enabled=false \
        --set ingress-nginx.enabled=false || \
        output error "Failed to restart host ${domain}"

    output success "Host ${domain} restarted successfully"
}

host_list() {
    output info "Current hosts:"
    helm list -A
}


restore_hosts() {
    if [[ ! -f "${RUNNING_HOSTS_FILE}" ]]; then
        output info "No saved hosts found to restore"
        return
    fi

    output info "Restoring previously running hosts..."

    while IFS= read -r host; do
        output info "Starting host: ${host}"
        helm install "${host}" "${CHART_DIR}" \
            --namespace ${APPS_NAMESPACE} \
            -f "./hosts/${host}/values.yaml" \
            --set cert-manager.enabled=false \
            --set ingress-nginx.enabled=false || \
            output error "Failed to restore host ${host}"
    done < "${RUNNING_HOSTS_FILE}"

    output success "Hosts restored successfully"
}

create_image_name() {
    local type=$1
    local version=$2
    echo "${NAME}-${type}:${version}"
}

# Function to validate inputs
validate_build_params() {
    local type=$1
    local version=$2

    # Check if type is provided
    if [[ -z "${type}" ]]; then
        output error "Type is required (e.g., php, node)"
    fi

    # Check if version is provided
    if [[ -z "${version}" ]]; then
        output error "Version is required (e.g., 8.2, 18)"
    fi

    # Check if directory exists
    if [[ ! -d "docker/${type}" ]]; then
        output error "Type '${type}' not found in docker directory"
    fi

    # Check if version directory exists
    if [[ ! -d "docker/${type}/${version}" ]]; then
        output error "Version '${version}' not found for type '${type}'"
    fi
}

# Function to build image
build_image() {
    local type=$1
    local version=$2
    local no_cache=${3:-false}
    local dockerfile_path="docker/${type}/${version}/Dockerfile"

    local image_name
    image_name=$(create_image_name "${type}" "${version}")

    # Validate parameters
    validate_build_params "${type}" "${version}"

    # Check if Dockerfile exists
    if [[ ! -f "${dockerfile_path}" ]]; then
        output error "Dockerfile not found at ${dockerfile_path}"
    fi

    echo "Building ${type} ${version} image..."
    echo "Using Dockerfile: ${dockerfile_path}"
    echo "Image name will be: ${image_name}"

    # Build command with optional no-cache
    if [[ "${no_cache}" == "--no-cache" ]]; then
        echo "Building with no cache..."
        if ! docker build --no-cache -t "${image_name}" -f "${dockerfile_path}" .; then
            output error "Failed to build ${image_name}"
        fi
    else
        if ! docker build -t "${image_name}" -f "${dockerfile_path}" .; then
            output error "Failed to build ${image_name}"
        fi
    fi

    output success "Successfully built ${image_name}"
}

show_help() {
    output info "${NAME} v${VERSION} - Local Development Environment Manager"
    output info "🪁 Sail through your local development with ease"
    echo

    output info "Usage:"
    echo "  ${NAME} [command] [arguments]"
    echo

    output info "Infrastructure Commands:"
    echo "  install     Install base infrastructure (ingress-nginx, cert-manager)"
    echo "  uninstall   Remove base infrastructure"
    echo "  reload      Reload/restart infrastructure"
    echo "  shutdown    Gracefully stop infrastructure without uninstalling"
    echo "  status      Check infrastructure and hosts status"
    echo

    output info "Host Management: (all require <domain> parameter)"
    echo "  create  <domain>    Create new host"
    echo "  start   <domain>    Start host"
    echo "  stop    <domain>    Stop host"
    echo "  restart <domain>    Restart host"
    echo "  list               List all running hosts"
    echo

    output info "Development Tools:"
    echo "  build <type> <version> [--no-cache]    Build custom Docker image"
    echo "  debug                                  Run infrastructure health check"
    echo "  help                                   Show this help message"
    echo

    output info "Examples:"
    echo "  ${NAME} install                     # Install infrastructure"
    echo "  ${NAME} create  www.domain.dev      # Create new host"
    echo "  ${NAME} start   www.domain.dev      # Start host"
    echo "  ${NAME} build   php 8.2             # Build PHP image"
    echo "  ${NAME} build   php 8.2 --no-cache  # Force rebuild ignoring cache"
    echo
}

# Main script
case "${1:-help}" in
    # Infrastructure commands
    install|uninstall|reload|shutdown|status|debug)
        check_requirements
        func="infra_${1}"
        if declare -F "$func" > /dev/null; then
            "$func"
        else
            output error "Infrastructure command not implemented: $1"
        fi
        ;;

    # Host commands
    create|start|stop|restart|list)
        check_requirements
        func="host_${1}"
        if declare -F "$func" > /dev/null; then
            if [ "$1" = "list" ]; then
                "$func"
                exit 0
            elif [ -z "${2:-}" ]; then
                output error "Domain required. Usage: ${NAME} $1 <domain>"
            fi
            "$func" "$2"
        else
            output error "Host command not implemented: $1"
        fi
        ;;
    build)
        if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
            output error "Usage: ${NAME} build <type> <version> [--no-cache]"
        fi
        check_requirements
        build_image "$2" "$3" "${4:-}"
        ;;
    version)
        echo "${NAME} version ${VERSION}"
        ;;
    help|*)
        show_help
        ;;
esac