-- Unleash Edge Frontend Load Test Script for wrk
-- Tests different user contexts with consolidated reporting

-- User context scenarios (distributed randomly)
local contexts = {
    {
        name = "EU Pro Desktop",
        data = '{"sessionId": "user_%d", "tld": "fr", "accountType": "pro", "platform": "desktop"}',
        weight = 25
    },
    {
        name = "US Patient Mobile",
        data = '{"sessionId": "user_%d", "tld": "us", "accountType": "patient", "platform": "mobile"}',
        weight = 30
    },
    {
        name = "DE Pro Web",
        data = '{"sessionId": "user_%d", "tld": "de", "accountType": "pro", "platform": "web"}',
        weight = 25
    },
    {
        name = "No Context GET",
        data = nil,  -- GET request
        weight = 20
    }
}

-- Calculate cumulative weights for random selection
local cumulative_weights = {}
local total_weight = 0
for i, context in ipairs(contexts) do
    total_weight = total_weight + context.weight
    cumulative_weights[i] = total_weight
end

-- Counters for each scenario
local scenario_counts = {}
local scenario_errors = {}
for i = 1, #contexts do
    scenario_counts[i] = 0
    scenario_errors[i] = 0
end

-- Thread setup
function setup(thread)
    math.randomseed(os.time() + os.clock() * 1000000)
end

-- Generate unique session IDs
local session_counter = 0
local function get_session_id()
    session_counter = session_counter + 1
    return session_counter
end

-- Select random context based on weights
local function select_context()
    local rand = math.random(1, total_weight)
    for i, weight in ipairs(cumulative_weights) do
        if rand <= weight then
            return i
        end
    end
    return 1  -- fallback
end

-- Build request for each scenario
function request()
    local context_index = select_context()
    local context = contexts[context_index]
    scenario_counts[context_index] = scenario_counts[context_index] + 1

    local headers = {}
    headers["Authorization"] = "default:development.unleash-insecure-frontend-api-token"

    if context.data then
        -- POST request with context
        headers["Content-Type"] = "application/json"
        local session_id = get_session_id()
        local body = string.format(context.data, session_id)
        return wrk.format("POST", nil, headers, body)
    else
        -- GET request without context
        return wrk.format("GET", nil, headers)
    end
end

-- Handle response
function response(status, headers, body)
    -- Track errors per scenario (simplified - we'd need thread-local storage for perfect accuracy)
    if status ~= 200 then
        -- This is approximate since we can't easily track which scenario this response belongs to
        -- For precise per-scenario error tracking, we'd need more complex state management
    end
end

-- Final statistics
function done(summary, latency, requests)
    -- Latency statistics
    print("\nLatency Distribution:")
    print(string.format("  50th percentile: %.2fms", latency:percentile(50) / 1000))
    print(string.format("  99th percentile: %.2fms", latency:percentile(99) / 1000))
    print(string.format("  99.9th percentile: %.2fms", latency:percentile(99.9) / 1000))
    print(string.format("  Max latency: %.2fms", latency.max / 1000))
    print(string.format("  Mean latency: %.2fms", latency.mean / 1000))

    -- Additional insights
    print("\nPerformance Insights:")
    local avg_latency_ms = latency.mean / 1000
    if avg_latency_ms < 10 then
        print("  ✓ Excellent response times (< 10ms)")
    elseif avg_latency_ms < 50 then
        print("  ✓ Good response times (< 50ms)")
    elseif avg_latency_ms < 100 then
        print("  ⚠ Acceptable response times (< 100ms)")
    else
        print("  ✗ High response times (> 100ms)")
    end

    local error_rate = ((summary.errors.status + summary.errors.read + summary.errors.write + summary.errors.timeout) / summary.requests) * 100
    if error_rate == 0 then
        print("  ✓ No errors detected")
    elseif error_rate < 1 then
        print(string.format("  ⚠ Low error rate (%.2f%%)", error_rate))
    else
        print(string.format("  ✗ High error rate (%.2f%%)", error_rate))
    end

    print(string.rep("=", 60))
end
