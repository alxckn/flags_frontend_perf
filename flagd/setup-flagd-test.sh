#!/bin/bash

# Setup flagd test environment
# Generates configuration and starts services

echo "========================================"
echo "Flagd Performance Test Setup"
echo "========================================"
echo "Timestamp: $(date)"
echo ""

# Generate flags configuration
echo "1. Generating flagd configuration..."
./generate-flagd-config.rb

if [ ! -f "flags.json" ]; then
    echo "Error: Failed to generate flags.json"
    exit 1
fi

echo "✓ Configuration generated successfully"
echo ""

# Validate JSON
echo "2. Validating JSON configuration..."
if command -v jq &> /dev/null; then
    if jq . flags.json > /dev/null 2>&1; then
        flag_count=$(jq '.flags | length' flags.json)
        echo "✓ JSON is valid with $flag_count flags"
    else
        echo "✗ JSON validation failed"
        exit 1
    fi
else
    echo "⚠ jq not available, skipping JSON validation"
fi

echo ""

# Start services
echo "3. Starting services with Docker Compose..."
docker compose up -d

if [ $? -ne 0 ]; then
    echo "✗ Failed to start services"
    exit 1
fi

echo "✓ Services started"
echo ""

# Wait for services to be healthy
echo "4. Waiting for services to be ready..."

echo -n "Waiting for nginx"
for i in {1..5}; do
    if curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo " ✓"
        break
    fi
    echo -n "."
    sleep 2
    if [ $i -eq 5 ]; then
        echo " ✗ Timeout"
        echo "nginx failed to start properly"
        docker compose logs nginx
        exit 1
    fi
done

echo -n "Waiting for flagd"
for i in {1..5}; do
    if curl -s http://localhost:8013/readyz > /dev/null 2>&1; then
        echo " ✓"
        break
    fi
    echo -n "."
    sleep 2
    if [ $i -eq 5 ]; then
        echo " ✗ Timeout"
        echo "flagd failed to start properly"
        docker compose logs flagd
        exit 1
    fi
done

echo ""

# Test endpoints
echo "5. Testing endpoints..."

# Test nginx config endpoint
echo -n "Testing nginx config endpoint... "
if curl -s http://localhost:8080/flags.json | jq . > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
    echo "Failed to fetch flags configuration from nginx"
    exit 1
fi

# Test flagd health endpoint
echo -n "Testing flagd health endpoint... "
health_response=$(curl -s http://localhost:8013/readyz)
if [ "$health_response" = "OK" ]; then
    echo "✓"
else
    echo "✗"
    echo "Flagd health check failed: $health_response"
    exit 1
fi

# Test flagd evaluation endpoint
echo -n "Testing flagd evaluation endpoint... "
test_response=$(curl -s -X POST http://localhost:8013/ofrep/v1/evaluate/flags/test-flag-0001 \
    -H "Content-Type: application/json" \
    -d '{"context": {"sessionId": "test-user"}}')

if echo "$test_response" | jq . > /dev/null 2>&1; then
    echo "✓"
else
    echo "✗"
    echo "Flagd evaluation test failed"
    echo "Response: $test_response"
    exit 1
fi

echo ""

# Display service information
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Services are now running:"
echo "• Nginx (config server): http://localhost:8080"
echo "  - Flags config: http://localhost:8080/flags.json"
echo "  - Health check: http://localhost:8080/health"
echo ""
echo "• Flagd (evaluation server): http://localhost:8013"
echo "  - Health check: http://localhost:8013/readyz"
echo "  - Evaluation API: http://localhost:8013/ofrep/v1/evaluate/flags/{flag-key}"
echo ""
echo "Configuration summary:"
echo "• Total flags: $(jq '.flags | length' flags.json 2>/dev/null || echo 'N/A')"
echo "• Enabled flags: ~300 (30%)"
echo "• Segmented flags: ~400 (40%)"
echo "• Disabled flags: ~300 (30%)"
echo ""
echo "Next steps:"
echo "1. Run load tests: ./run-flagd-test.sh"
echo "2. Monitor performance: docker stats"
echo "3. View logs: docker compose logs -f"
echo ""
echo "To stop services: docker compose down"
