#!/bin/bash

#################################################################################
# Build Script for Sayf Project
# This script builds Docker images and pushes them to Docker Hub
# Usage: ./build.sh [dev|prod] [--push] [--tag TAG_NAME]
#################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-sayfops}"
PROJECT_NAME="e-commerce-app"
IMAGE_NAME_DEV="${DOCKER_HUB_USERNAME}/e-commerce-dev"
IMAGE_NAME_PROD="${DOCKER_HUB_USERNAME}/e-commerce-prod"
REGISTRY="docker.io"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Default values
ENVIRONMENT="dev"
SHOULD_PUSH=false
CUSTOM_TAG=""
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

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

#################################################################################
# Function: Display help
#################################################################################
show_help() {
    cat << EOF
Usage: ./build.sh [OPTIONS]

OPTIONS:
    dev              Build for development environment (default)
    prod             Build for production environment
    --push           Push image to Docker Hub after building
    --tag TAG_NAME   Custom tag for the image (default: timestamp + git commit)
    --help           Display this help message

EXAMPLES:
    # Build dev image locally
    ./build.sh dev

    # Build and push dev image to Docker Hub
    ./build.sh dev --push

    # Build prod image with custom tag
    ./build.sh prod --tag v1.0.0 --push

    # Build with environment variables
    DOCKER_HUB_USERNAME=myusername ./build.sh dev --push

ENVIRONMENT VARIABLES:
    DOCKER_HUB_USERNAME    Docker Hub username (default: your-dockerhub-username)

EOF
    exit 0
}

#################################################################################
# Function: Validate Docker installation
#################################################################################
validate_docker() {
    print_info "Checking Docker installation..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    print_success "Docker found: $(docker --version)"

    # Check if Docker daemon is running
    if ! docker ps &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi

    print_success "Docker daemon is running"
}

#################################################################################
# Function: Validate prerequisites
#################################################################################
validate_prerequisites() {
    print_info "Validating prerequisites..."

    # Check if Dockerfile exists
    if [[ ! -f "Dockerfile" ]]; then
        print_error "Dockerfile not found in current directory"
        exit 1
    fi
    print_success "Dockerfile found"

    # Check if docker-compose.yml exists
    if [[ ! -f "docker-compose.yml" ]]; then
        print_error "docker-compose.yml not found in current directory"
        exit 1
    fi
    print_success "docker-compose.yml found"

    # Check if nginx.conf exists
    if [[ ! -f "nginx.conf" ]]; then
        print_error "nginx.conf not found in current directory"
        exit 1
    fi
    print_success "nginx.conf found"

    # Check if build directory exists
    if [[ ! -d "devops-build/build" ]]; then
        print_error "devops-build/build directory not found"
        exit 1
    fi
    print_success "devops-build/build directory found"
}

#################################################################################
# Function: Build Docker image
#################################################################################
build_image() {
    local image_name=$1
    local tag=$2
    local full_image_tag="${image_name}:${tag}"

    print_info "Building Docker image: ${full_image_tag}"

    # Build with build arguments
    docker build \
        --tag "${full_image_tag}" \
        --tag "${image_name}:latest" \
        --label "build.date=${BUILD_DATE}" \
        --label "git.commit=${GIT_COMMIT}" \
        --label "environment=${ENVIRONMENT}" \
        . || {
            print_error "Docker build failed"
            exit 1
        }

    print_success "Image built successfully: ${full_image_tag}"

    # Print image info
    print_info "Image information:"
    docker images | grep "${image_name}" | head -2
}

#################################################################################
# Function: Login to Docker Hub
#################################################################################
docker_login() {
    print_info "Checking Docker Hub authentication..."

    if [[ "${DOCKER_HUB_USERNAME}" == "your-dockerhub-username" ]]; then
        print_warning "DOCKER_HUB_USERNAME is not set or using default value"
        print_info "Please set DOCKER_HUB_USERNAME environment variable:"
        print_info "export DOCKER_HUB_USERNAME=your-actual-username"
        return 1
    fi

    # Check if already logged in
    if grep -q "\"auths\"" ~/.docker/config.json 2>/dev/null; then
        print_success "Already authenticated to Docker Hub"
        return 0
    fi

    print_warning "Not authenticated to Docker Hub. Attempting login..."
    docker login || {
        print_error "Docker Hub login failed"
        return 1
    }
}

#################################################################################
# Function: Push image to Docker Hub
#################################################################################
push_image() {
    local image_name=$1
    local tag=$2
    local full_image_tag="${image_name}:${tag}"

    print_info "Pushing image to Docker Hub: ${full_image_tag}"

    if ! docker_login; then
        print_error "Cannot push without Docker Hub authentication"
        return 1
    fi

    docker push "${full_image_tag}" || {
        print_error "Failed to push image: ${full_image_tag}"
        return 1
    }

    # Also push latest tag
    docker push "${image_name}:latest" || {
        print_error "Failed to push latest tag"
        return 1
    }

    print_success "Image pushed successfully"
    print_info "Image pushed to: ${full_image_tag}"
}

#################################################################################
# Function: Generate image tag
#################################################################################
generate_tag() {
    if [[ -n "${CUSTOM_TAG}" ]]; then
        echo "${CUSTOM_TAG}"
    else
        echo "${TIMESTAMP}_${GIT_COMMIT}"
    fi
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
            --push)
                SHOULD_PUSH=true
                shift
                ;;
            --tag)
                CUSTOM_TAG="$2"
                shift 2
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
# Function: Main execution
#################################################################################
main() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          Sayf Project - Docker Build Script               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Validate prerequisites
    validate_docker
    validate_prerequisites

    # Set image name based on environment
    if [[ "${ENVIRONMENT}" == "prod" ]]; then
        IMAGE_NAME="${IMAGE_NAME_PROD}"
    else
        IMAGE_NAME="${IMAGE_NAME_DEV}"
    fi

    # Generate tag
    TAG=$(generate_tag)

    print_info "Build Configuration:"
    print_info "  Environment: ${ENVIRONMENT}"
    print_info "  Docker Hub Username: ${DOCKER_HUB_USERNAME}"
    print_info "  Image Name: ${IMAGE_NAME}"
    print_info "  Tag: ${TAG}"
    print_info "  Push to Registry: ${SHOULD_PUSH}"
    print_info "  Git Commit: ${GIT_COMMIT}"
    echo ""

    # Build image
    build_image "${IMAGE_NAME}" "${TAG}"
    echo ""

    # Push to Docker Hub if requested
    if [[ "${SHOULD_PUSH}" == true ]]; then
        push_image "${IMAGE_NAME}" "${TAG}"
        echo ""
        print_success "Push complete!"
    else
        print_info "Skipping push to Docker Hub (use --push flag to push)"
        echo ""
    fi

    # Summary
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    BUILD COMPLETED                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Next steps:"

    if [[ "${SHOULD_PUSH}" == true ]]; then
        print_info "  1. Image has been pushed to: ${IMAGE_NAME}:${TAG}"
        print_info "  2. Run deploy.sh to deploy the image"
    else
        print_info "  1. Run locally: docker run -p 3000:80 ${IMAGE_NAME}:${TAG}"
        print_info "  2. Or push with: ./build.sh ${ENVIRONMENT} --push --tag ${TAG}"
        print_info "  3. Then run deploy.sh to deploy the image"
    fi
    echo ""
}

# Run main function
main "$@"
