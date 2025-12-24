#!/bin/bash

#################################################################################
# Deploy Script for Sayf Project
# This script deploys Docker images from Docker Hub to a production server
# Usage: ./deploy.sh [OPTIONS]
#################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-sayfops}"
PROJECT_NAME="e-commerce-app"
IMAGE_NAME_DEV="${DOCKER_HUB_USERNAME}/e-commerce-dev"
IMAGE_NAME_PROD="${DOCKER_HUB_USERNAME}/e-commerce-prod"

# Server Configuration (Update these with your actual server details)
SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-ubuntu}"
SERVER_PORT="${SERVER_PORT:-22}"
SERVER_APP_DIR="${SERVER_APP_DIR:-/opt/sayf-app}"
CONTAINER_PORT=3000
HOST_PORT=80

# Default values
ENVIRONMENT="dev"
IMAGE_TAG="latest"
SHOULD_ROLLBACK=false
HEALTH_CHECK_TIMEOUT=60

#################################################################################
# Function: Print colored output
#################################################################################
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_step() {
    echo -e "${CYAN}→ $1${NC}"
}

#################################################################################
# Function: Display help
#################################################################################
show_help() {
    cat << EOF
Usage: ./deploy.sh [OPTIONS]

OPTIONS:
    dev              Deploy to development environment (default)
    prod             Deploy to production environment
    --tag TAG_NAME   Specify image tag to deploy (default: latest)
    --host HOST      Server hostname/IP
    --user USER      SSH username (default: ubuntu)
    --port PORT      SSH port (default: 22)
    --app-dir DIR    Application directory on server (default: /opt/sayf-app)
    --rollback       Rollback to previous deployment
    --help           Display this help message

EXAMPLES:
    # Deploy dev image to server
    ./deploy.sh dev --host 192.168.1.100 --user ubuntu

    # Deploy specific tag to production
    ./deploy.sh prod --tag v1.0.0 --host prod-server.com --user deploy

    # Deploy with custom SSH port
    ./deploy.sh dev --host example.com --port 2222 --user ubuntu

ENVIRONMENT VARIABLES:
    DOCKER_HUB_USERNAME    Docker Hub username
    SERVER_HOST            Server hostname/IP
    SERVER_USER            SSH username
    SERVER_PORT            SSH port
    SERVER_APP_DIR         Application directory on server

EOF
    exit 0
}

#################################################################################
# Function: Validate prerequisites
#################################################################################
validate_prerequisites() {
    print_info "Validating prerequisites..."

    # Check SSH availability
    if ! command -v ssh &> /dev/null; then
        print_error "SSH is not installed"
        exit 1
    fi
    print_success "SSH found"

    # Check if server details are provided
    if [[ -z "${SERVER_HOST}" ]]; then
        print_error "Server host is not specified. Use --host option or SERVER_HOST environment variable"
        exit 1
    fi

    # Validate SSH connection
    print_info "Testing SSH connection to ${SERVER_USER}@${SERVER_HOST}:${SERVER_PORT}..."
    if ! ssh -o ConnectTimeout=5 -p "${SERVER_PORT}" "${SERVER_USER}@${SERVER_HOST}" "echo 'SSH connection successful'" > /dev/null 2>&1; then
        print_error "Cannot connect to server. Check host, user, and port"
        exit 1
    fi
    print_success "SSH connection established"

    # Check if Docker is installed on server
    print_info "Checking Docker on remote server..."
    if ! ssh -p "${SERVER_PORT}" "${SERVER_USER}@${SERVER_HOST}" "which docker" > /dev/null 2>&1; then
        print_error "Docker is not installed on the server"
        print_info "Please install Docker on the server first"
        exit 1
    fi
    print_success "Docker is installed on server"
}

#################################################################################
# Function: Parse command line arguments
#################################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            dev)
                ENVIRONMENT="dev"
                shift
                ;;
            prod)
                ENVIRONMENT="prod"
                shift
                ;;
            --tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            --host)
                SERVER_HOST="$2"
                shift 2
                ;;
            --user)
                SERVER_USER="$2"
                shift 2
                ;;
            --port)
                SERVER_PORT="$2"
                shift 2
                ;;
            --app-dir)
                SERVER_APP_DIR="$2"
                shift 2
                ;;
            --rollback)
                SHOULD_ROLLBACK=true
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

#################################################################################
# Function: Execute remote command
#################################################################################
execute_remote() {
    local cmd=$1
    ssh -p "${SERVER_PORT}" "${SERVER_USER}@${SERVER_HOST}" "${cmd}"
}

#################################################################################
# Function: Copy file to remote server
#################################################################################
copy_to_remote() {
    local local_file=$1
    local remote_path=$2

    print_info "Copying ${local_file} to server..."
    scp -P "${SERVER_PORT}" "${local_file}" "${SERVER_USER}@${SERVER_HOST}:${remote_path}" || {
        print_error "Failed to copy file to server"
        return 1
    }
    print_success "File copied successfully"
}

#################################################################################
# Function: Setup application directory on server
#################################################################################
setup_server_directory() {
    print_step "Setting up application directory on server"

    execute_remote "mkdir -p ${SERVER_APP_DIR}" || {
        print_error "Failed to create application directory"
        return 1
    }

    execute_remote "mkdir -p ${SERVER_APP_DIR}/backups" || {
        print_error "Failed to create backups directory"
        return 1
    }

    print_success "Application directory ready"
}

#################################################################################
# Function: Backup current deployment
#################################################################################
backup_current_deployment() {
    print_step "Backing up current deployment"

    local backup_file="docker-compose-backup-$(date +%Y%m%d_%H%M%S).yml"

    # Check if docker-compose.yml exists on server
    if execute_remote "test -f ${SERVER_APP_DIR}/docker-compose.yml" 2>/dev/null; then
        execute_remote "cp ${SERVER_APP_DIR}/docker-compose.yml ${SERVER_APP_DIR}/backups/${backup_file}" || {
            print_warning "Failed to backup docker-compose.yml"
        }
        print_success "Backup created: ${backup_file}"
    else
        print_info "No previous deployment to backup"
    fi
}

#################################################################################
# Function: Copy docker-compose file to server
#################################################################################
deploy_docker_compose() {
    print_step "Deploying docker-compose configuration"

    # Update docker-compose file with correct image name and tag
    local temp_compose=$(mktemp)
    sed "s|{{IMAGE_NAME}}|${IMAGE_NAME}:${IMAGE_TAG}|g" docker-compose.yml > "${temp_compose}"

    copy_to_remote "${temp_compose}" "${SERVER_APP_DIR}/docker-compose.yml"
    rm "${temp_compose}"

    print_success "Docker-compose file deployed"
}

#################################################################################
# Function: Pull and run container
#################################################################################
run_container() {
    print_step "Pulling and running Docker container"

    if [[ "${ENVIRONMENT}" == "prod" ]]; then
        IMAGE_NAME="${IMAGE_NAME_PROD}"
    else
        IMAGE_NAME="${IMAGE_NAME_DEV}"
    fi

    execute_remote "cd ${SERVER_APP_DIR} && docker-compose pull" || {
        print_error "Failed to pull image from Docker Hub"
        return 1
    }
    print_success "Image pulled successfully"

    # Stop existing containers
    print_info "Stopping existing containers..."
    execute_remote "cd ${SERVER_APP_DIR} && docker-compose down" 2>/dev/null || true

    # Start new containers
    print_info "Starting new containers..."
    execute_remote "cd ${SERVER_APP_DIR} && docker-compose up -d" || {
        print_error "Failed to start containers"
        return 1
    }
    print_success "Containers started successfully"
}

#################################################################################
# Function: Health check
#################################################################################
health_check() {
    print_step "Performing health check"

    local elapsed=0
    local interval=5

    while [[ ${elapsed} -lt ${HEALTH_CHECK_TIMEOUT} ]]; do
        print_info "Checking application health (${elapsed}s/${HEALTH_CHECK_TIMEOUT}s)..."

        if execute_remote "curl -f -s http://localhost/ > /dev/null" 2>/dev/null; then
            print_success "Application is healthy"
            return 0
        fi

        sleep ${interval}
        elapsed=$((elapsed + interval))
    done

    print_error "Health check failed after ${HEALTH_CHECK_TIMEOUT} seconds"
    return 1
}

#################################################################################
# Function: Verify deployment
#################################################################################
verify_deployment() {
    print_step "Verifying deployment"

    # Check running containers
    print_info "Running containers:"
    execute_remote "docker-compose -f ${SERVER_APP_DIR}/docker-compose.yml ps"

    # Check logs
    print_info "Recent logs:"
    execute_remote "docker-compose -f ${SERVER_APP_DIR}/docker-compose.yml logs --tail=10"
}

#################################################################################
# Function: Rollback deployment
#################################################################################
rollback_deployment() {
    print_step "Rolling back to previous deployment"

    # Find the latest backup
    local latest_backup=$(execute_remote "ls -t ${SERVER_APP_DIR}/backups/docker-compose-backup-*.yml 2>/dev/null | head -1" || echo "")

    if [[ -z "${latest_backup}" ]]; then
        print_error "No backup found for rollback"
        return 1
    fi

    print_info "Restoring from: ${latest_backup}"

    # Restore backup
    execute_remote "cp ${latest_backup} ${SERVER_APP_DIR}/docker-compose.yml" || {
        print_error "Failed to restore backup"
        return 1
    }

    # Restart containers
    execute_remote "cd ${SERVER_APP_DIR} && docker-compose down && docker-compose up -d" || {
        print_error "Failed to restart containers"
        return 1
    }

    print_success "Rollback completed successfully"
}

#################################################################################
# Function: Display deployment summary
#################################################################################
display_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              DEPLOYMENT COMPLETED SUCCESSFULLY             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    print_info "Deployment Summary:"
    print_info "  Environment: ${ENVIRONMENT}"
    print_info "  Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    print_info "  Server: ${SERVER_USER}@${SERVER_HOST}:${SERVER_PORT}"
    print_info "  Application URL: http://${SERVER_HOST}/"
    print_info "  App Directory: ${SERVER_APP_DIR}"
    echo ""

    print_info "Useful commands:"
    print_info "  Check logs: ssh -p ${SERVER_PORT} ${SERVER_USER}@${SERVER_HOST} 'cd ${SERVER_APP_DIR} && docker-compose logs -f'"
    print_info "  Restart app: ssh -p ${SERVER_PORT} ${SERVER_USER}@${SERVER_HOST} 'cd ${SERVER_APP_DIR} && docker-compose restart'"
    print_info "  Stop app: ssh -p ${SERVER_PORT} ${SERVER_USER}@${SERVER_HOST} 'cd ${SERVER_APP_DIR} && docker-compose down'"
    echo ""
}

#################################################################################
# Function: Main execution
#################################################################################
main() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Sayf Project - Docker Deploy Script                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Set image name based on environment
    if [[ "${ENVIRONMENT}" == "prod" ]]; then
        IMAGE_NAME="${IMAGE_NAME_PROD}"
    else
        IMAGE_NAME="${IMAGE_NAME_DEV}"
    fi

    print_info "Deployment Configuration:"
    print_info "  Environment: ${ENVIRONMENT}"
    print_info "  Docker Hub Username: ${DOCKER_HUB_USERNAME}"
    print_info "  Image Name: ${IMAGE_NAME}"
    print_info "  Image Tag: ${IMAGE_TAG}"
    print_info "  Server: ${SERVER_USER}@${SERVER_HOST}:${SERVER_PORT}"
    print_info "  App Directory: ${SERVER_APP_DIR}"
    echo ""

    # Handle rollback
    if [[ "${SHOULD_ROLLBACK}" == true ]]; then
        print_warning "Rolling back to previous deployment"
        validate_prerequisites
        rollback_deployment
        display_summary
        exit 0
    fi

    # Validate prerequisites
    validate_prerequisites

    # Setup and deploy
    setup_server_directory
    backup_current_deployment
    deploy_docker_compose
    run_container

    # Verify deployment
    if health_check; then
        verify_deployment
        display_summary
    else
        print_warning "Health check failed. Consider rolling back with: ./deploy.sh ${ENVIRONMENT} --host ${SERVER_HOST} --rollback"
        return 1
    fi
}

# Run main function
main "$@"
