#!/bin/bash

# Comprehensive Unleash Edge Frontend Load Test using wrk
# More sophisticated than ab with consolidated reporting

EDGE_URL="http://localhost:3064"
SCRIPT_FILE="unleash-edge-test.lua"

echo "========================================"
echo "Unleash Edge Frontend Load Test (wrk)"
echo "========================================"
echo "Target: $EDGE_URL"
echo "Test script: $SCRIPT_FILE"
echo "Timestamp: $(date)"
echo ""

# Test configurations - adjust these as needed
TEST_CONFIGS=(
    # threads:connections:duration:description
    "2:10:30s:Light Load (10 connections, 30s)"
    "4:25:60s:Medium Load (25 connections, 1min)"
    "8:50:60s:Heavy Load (50 connections, 1min)"
    "12:100:30s:Stress Test (100 connections, 30s)"
)

# Function to run a single wrk test
run_wrk_test() {
    local threads=$1
    local connections=$2
    local duration=$3
    local description="$4"

    echo "----------------------------------------"
    echo "Test: $description"
    echo "Configuration: $threads threads, $connections connections, $duration duration"
    echo "----------------------------------------"

    # Run wrk with our Lua script
    wrk -t$threads -c$connections -d$duration -s "$SCRIPT_FILE" "$EDGE_URL/api/frontend"

    echo ""
    echo "Waiting 5 seconds before next test..."
    sleep 5
}

# Check if wrk is installed
if ! command -v wrk &> /dev/null; then
    echo "Error: wrk is not installed"
    echo "Install with: sudo apt install wrk"
    echo "Or build from source: https://github.com/wg/wrk"
    exit 1
fi

# Check if script file exists
if [ ! -f "$SCRIPT_FILE" ]; then
    echo "Error: Script file $SCRIPT_FILE not found"
    exit 1
fi

curl -s "http://localhost:3064/api/client/features" -H "Authorization: default:development.unleash-insecure-client-api-token" > /dev/null && echo "Frontend Edge primed"

# Test endpoint availability
echo "Testing endpoint availability..."
response=$(curl -s -w "%{http_code}" -H "Authorization: default:development.unleash-insecure-frontend-api-token" "$EDGE_URL/api/frontend" -o /dev/null)
if [ "$response" != "200" ]; then
    echo "Error: Endpoint returned HTTP $response"
    echo "Make sure Unleash Edge Frontend is running and accessible"
    exit 1
fi

feature_count=$(curl -s -H "Authorization: default:development.unleash-insecure-frontend-api-token" "$EDGE_URL/api/frontend" | jq '.toggles | length' 2>/dev/null || echo "0")
echo "✓ Endpoint accessible, returning $feature_count features"
echo ""

# Run test suite
echo "Starting test suite with multiple load levels..."
echo ""

for config in "${TEST_CONFIGS[@]}"; do
    IFS=':' read -r threads connections duration description <<< "$config"
    run_wrk_test "$threads" "$connections" "$duration" "$description"
done

echo "========================================"
echo "All tests completed!"
echo "========================================"

# Summary and recommendations
echo ""
echo "RECOMMENDATIONS:"
echo "• Monitor server resources (CPU, memory) during high load tests"
echo "• Check Unleash Edge logs for any errors or warnings"
echo "• Compare results across different user contexts"
echo "• Consider tuning FEATURES_REFRESH_INTERVAL_SECONDS if needed"
echo ""
echo "For more detailed analysis:"
echo "• Check docker logs unleash_tests-unleash-edge-frontend-1"
echo "• Monitor with: docker stats unleash_tests-unleash-edge-frontend-1"
