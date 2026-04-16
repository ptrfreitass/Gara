# scripts/dev-down.sh
#!/bin/bash

echo "🛑 Parando ambiente de desenvolvimento..."

docker-compose -f docker-compose.dev.yml down

echo "✅ Ambiente parado!"