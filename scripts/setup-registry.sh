#!/bin/bash
# Setup local Docker registry for NexaNest

set -e

REGISTRY_HOST=${REGISTRY_HOST:-localhost}
REGISTRY_PORT=${REGISTRY_PORT:-5000}
REGISTRY_URL="${REGISTRY_HOST}:${REGISTRY_PORT}"

echo "🐳 Setting up local Docker registry"
echo "=================================="

# Check if registry is already running
if curl -s "http://${REGISTRY_URL}/v2/" > /dev/null 2>&1; then
    echo "✅ Registry is already running at ${REGISTRY_URL}"
else
    echo "Starting local Docker registry..."
    docker run -d \
        --restart=always \
        --name nexanest-registry \
        -p ${REGISTRY_PORT}:5000 \
        -v nexanest-registry:/var/lib/registry \
        registry:2
    
    echo "Waiting for registry to start..."
    sleep 5
    
    if curl -s "http://${REGISTRY_URL}/v2/" > /dev/null 2>&1; then
        echo "✅ Registry started successfully at ${REGISTRY_URL}"
    else
        echo "❌ Failed to start registry"
        exit 1
    fi
fi

# Create build script
cat > scripts/build-and-push.sh << 'EOF'
#!/bin/bash
# Build and push Docker images to local registry

set -e

REGISTRY_URL="${REGISTRY_URL:-localhost:5000}"
VERSION="${VERSION:-latest}"

echo "🔨 Building and pushing NexaNest images"
echo "Registry: ${REGISTRY_URL}"
echo "Version: ${VERSION}"
echo ""

# Build base images
echo "Building base images..."
docker pull redis:7-alpine
docker tag redis:7-alpine ${REGISTRY_URL}/nexanest/redis:7-alpine
docker push ${REGISTRY_URL}/nexanest/redis:7-alpine

docker pull confluentinc/cp-kafka:7.5.0
docker tag confluentinc/cp-kafka:7.5.0 ${REGISTRY_URL}/nexanest/kafka:7.5.0
docker push ${REGISTRY_URL}/nexanest/kafka:7.5.0

docker pull confluentinc/cp-zookeeper:7.5.0
docker tag confluentinc/cp-zookeeper:7.5.0 ${REGISTRY_URL}/nexanest/zookeeper:7.5.0
docker push ${REGISTRY_URL}/nexanest/zookeeper:7.5.0

docker pull kong:3.4-alpine
docker tag kong:3.4-alpine ${REGISTRY_URL}/nexanest/kong:3.4-alpine
docker push ${REGISTRY_URL}/nexanest/kong:3.4-alpine

docker pull opensearchproject/opensearch:2.11.0
docker tag opensearchproject/opensearch:2.11.0 ${REGISTRY_URL}/nexanest/opensearch:2.11.0
docker push ${REGISTRY_URL}/nexanest/opensearch:2.11.0

# Build service images
echo ""
echo "Building service images..."

# Auth Service
echo "Building auth-service..."
docker build -t ${REGISTRY_URL}/nexanest/auth-service:${VERSION} \
    -f services/auth/Dockerfile \
    services/auth/
docker push ${REGISTRY_URL}/nexanest/auth-service:${VERSION}

# Portfolio Service (when ready)
if [ -f "services/portfolio/Dockerfile" ]; then
    echo "Building portfolio-service..."
    docker build -t ${REGISTRY_URL}/nexanest/portfolio-service:${VERSION} \
        -f services/portfolio/Dockerfile \
        services/portfolio/
    docker push ${REGISTRY_URL}/nexanest/portfolio-service:${VERSION}
fi

# Documentation
echo "Building documentation..."
docker build -t ${REGISTRY_URL}/nexanest/docs:${VERSION} \
    -f infrastructure/docker/docs.Dockerfile \
    .
docker push ${REGISTRY_URL}/nexanest/docs:${VERSION}

echo ""
echo "✅ All images built and pushed successfully!"
echo ""
echo "Images available:"
docker images | grep "${REGISTRY_URL}/nexanest"
EOF

chmod +x scripts/build-and-push.sh

# Create Docker daemon configuration for insecure registry (development only)
echo ""
echo "⚠️  Note: For development, you may need to configure Docker to allow insecure registry."
echo "Add the following to your Docker daemon configuration:"
echo ""
echo "  {
    \"insecure-registries\": [\"${REGISTRY_URL}\"]
  }"
echo ""
echo "Location:"
echo "  - Linux: /etc/docker/daemon.json"
echo "  - Mac/Windows: Docker Desktop > Settings > Docker Engine"
echo ""
echo "Then restart Docker daemon."
echo ""
echo "✅ Registry setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure Docker daemon for insecure registry (if needed)"
echo "2. Build and push images: ./scripts/build-and-push.sh"
echo "3. Deploy to Swarm: docker stack deploy -c docker-compose.swarm.yml nexanest"