#!/bin/bash

# Comprehensive Flagd Load Test using wrk
# Similar to Unleash tests but adapted for flagd evaluation API

FLAGD_URL="http://localhost:8016"
SCRIPT_FILE="flagd-test.lua"

echo "========================================"
echo "Flagd Performance Load Test (wrk)"
echo "========================================"
echo "Target: $FLAGD_URL"
echo "Test script: $SCRIPT_FILE"
echo "Timestamp: $(date)"
echo ""

# Test configurations - same as Unleash for comparison
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

    # Run wrk with our Lua script against the OFREP bulk evaluation endpoint
    wrk -t$threads -c$connections -d$duration -s "$SCRIPT_FILE" "$FLAGD_URL/ofrep/v1/evaluate/flags"

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

# Test bulk evaluation endpoint
echo -n "Testing bulk evaluation endpoint... "
test_response=$(curl -s -X POST "$FLAGD_URL/ofrep/v1/evaluate/flags" \
    -H "Content-Type: application/json" \
    -d '{"context": {"sessionId": "test-user"}}' 2>/dev/null)

if echo "$test_response" | jq . > /dev/null 2>&1; then
    flag_count=$(echo "$test_response" | jq '. | length' 2>/dev/null)
    echo "✓ Endpoint accessible, returned $flag_count flags"
else
    echo "✗ Bulk evaluation endpoint test failed"
    echo "Response: $test_response"
    exit 1
fi

# Check config source
echo -n "Testing config source... "
config_response=$(curl -s "http://localhost:8080/flags.json" 2>/dev/null)
if echo "$config_response" | jq . > /dev/null 2>&1; then
    flag_count=$(echo "$config_response" | jq '.flags | length' 2>/dev/null)
    echo "✓ Config accessible with $flag_count flags"
else
    echo "✗ Config source not accessible"
    echo "Make sure nginx is running with the config"
    exit 1
fi

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
echo "• Monitor flagd container resources (CPU, memory) during high load tests"
echo "• Check flagd logs for any errors or warnings: docker compose logs flagd"
echo "• Compare results with Unleash Edge performance"
echo "• Consider tuning FLAGD_SYNC_PROVIDER_POLL_INTERVAL if needed"
echo ""
echo "For more detailed analysis:"
echo "• Monitor with: docker stats"
echo "• View container logs: docker compose logs -f"
echo "• Test bulk evaluation: curl -X POST $FLAGD_URL/ofrep/v1/evaluate/flags -H 'Content-Type: application/json' -d '{\"context\": {\"sessionId\": \"user123\"}}'"
echo ""
echo "Flag distribution tested:"
echo "• Enabled flags (test-flag-0001 to test-flag-0300)"
echo "• Segmented flags (test-flag-0301 to test-flag-0700)"
echo "• Disabled flags (test-flag-0701 to test-flag-1000)"
