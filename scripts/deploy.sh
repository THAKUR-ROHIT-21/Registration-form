#!/bin/bash

set -Eeuo pipefail

PROJECT_DIR="/home/rohit/gcp-user-registration-atlas"
APP_DIR="${PROJECT_DIR}/app"
BRANCH="main"

echo "======================================"
echo "GCP application deployment started"
echo "======================================"

cd "${PROJECT_DIR}"

echo "Fetching latest code..."
git fetch origin "${BRANCH}"

echo "Resetting server code to GitHub main..."
git reset --hard "origin/${BRANCH}"

cd "${APP_DIR}"

if [ ! -f "docker-compose.yml" ]; then
    echo "ERROR: docker-compose.yml not found in ${APP_DIR}"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "ERROR: ${APP_DIR}/.env file not found"
    echo "Create .env manually on the VM."
    exit 1
fi

echo "Validating Docker Compose..."
docker compose config --quiet

echo "Building Docker images..."
docker compose build --pull

echo "Starting containers..."
docker compose up -d --remove-orphans

echo "Waiting for application..."
sleep 15

echo "Checking container status..."
docker compose ps

echo "Checking backend health..."

for attempt in {1..12}; do
    if curl --fail --silent http://127.0.0.1/api/health > /dev/null; then
        echo "Application health check passed."
        docker image prune -f

        echo "======================================"
        echo "Deployment completed successfully"
        echo "======================================"
        exit 0
    fi

    echo "Health check attempt ${attempt}/12 failed. Retrying..."
    sleep 5
done

echo "ERROR: Application health check failed."

echo "Nginx logs:"
docker compose logs --tail=50 nginx || true

echo "Backend logs:"
docker compose logs --tail=50 backend || true

exit 1
