# scripts/push.sh
#!/bin/bash

set -e

VERSION=$1
DOCKER_USERNAME=${DOCKER_USERNAME:-"preetow"}

if [ -z "$VERSION" ]; then
    echo "❌ Uso: ./push.sh <versao>"
    echo "   Exemplo: ./push.sh 1.0.0"
    exit 1
fi

echo "📤 Pushing images version $VERSION to Docker Hub..."
echo ""

# Push backend
echo "📤 Pushing backend..."
docker push $DOCKER_USERNAME/gara_backend:$VERSION
docker push $DOCKER_USERNAME/gara_backend:latest
echo "✅ Backend pushed!"
echo ""

# Push frontend
echo "📤 Pushing frontend..."
docker push $DOCKER_USERNAME/gara_frontend:$VERSION
docker push $DOCKER_USERNAME/gara_frontend:latest
echo "✅ Frontend pushed!"
echo ""

echo "✅ Push completed!"
echo ""
echo "🚀 Próximo passo: ./scripts/deploy.sh $VERSION"