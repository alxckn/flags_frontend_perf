# Unleash Feature Flag Testing Environment

This repository contains a complete testing environment for Unleash feature flags with Edge proxy deployments, including load testing tools and capacity planning.

## Architecture

- **Unleash Server**: Main feature flag management server
- **PostgreSQL**: Database for Unleash server
- **Unleash Edge (Client)**: Port 3063 - For backend/server-side applications
- **Unleash Edge (Frontend)**: Port 3064 - For frontend/client-side applications

## Quick Start

### 1. Launch Docker Environment

```bash
# Start all services
docker compose up -d

# Check service status
docker compose ps
```

**Services will be available at:**
- Unleash UI: http://localhost:4242 (admin/unleash4all)
- Unleash Edge Client: http://localhost:3063
- Unleash Edge Frontend: http://localhost:3064

### 2. Seed the Database

```bash
# Run the setup script to create 1000 test feature flags
./setup-test-flags.sh
```

**This creates:**
- 300 flags (30%): Fully activated
- 400 flags (40%): Segmented with random rollout percentages
- 300 flags (30%): Disabled
- 5 user segments: EU users, Pro users, Patient users, Mobile users, Desktop users

### 3. Prime the Frontend Edge

**Important**: The frontend Edge needs to be primed after seeding or container restarts:

```bash
# Prime frontend Edge with client data
curl -s "http://localhost:3064/api/client/features" \
  -H "Authorization: default:development.unleash-insecure-client-api-token" > /dev/null

# Verify it's working
curl -s "http://localhost:3064/api/frontend" \
  -H "Authorization: default:development.unleash-insecure-frontend-api-token" | jq '.toggles | length'
```

Should return `700` (enabled features).

## Load Testing

### 4. Monitor Container Resources

In a separate terminal, monitor the frontend Edge performance:

```bash
# Real-time stats
docker stats unleash_tests-unleash-edge-frontend-1

# Continuous monitoring with timestamps
while true; do 
  echo "$(date): $(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" unleash_tests-unleash-edge-frontend-1)"
  sleep 5
done
```

### 5. Run Load Tests

```bash
# Install wrk if needed
sudo apt install wrk

# Run comprehensive load test suite
./run-wrk-test.sh
```

**Test scenarios:**
- Light Load: 2 threads, 10 connections, 30s
- Medium Load: 4 threads, 25 connections, 1min  
- Heavy Load: 8 threads, 50 connections, 1min
- Stress Test: 12 threads, 100 connections, 30s

**User contexts tested:**
- EU Pro Desktop users (25% weight)
- US Patient Mobile users (30% weight)  
- DE Pro Web users (25% weight)
- No context GET requests (20% weight)

## API Endpoints

### Client API (Backend)
```bash
# Get features for backend applications
curl -H "Authorization: default:development.unleash-insecure-client-api-token" \
  http://localhost:3063/api/client/features
```

### Frontend API (Client-side)
```bash
# Get toggles for frontend applications
curl -H "Authorization: default:development.unleash-insecure-frontend-api-token" \
  http://localhost:3064/api/frontend

# With user context
curl -H "Authorization: default:development.unleash-insecure-frontend-api-token" \
  -H "Content-Type: application/json" \
  -d '{"sessionId": "user123", "tld": "fr", "accountType": "pro", "platform": "mobile"}' \
  http://localhost:3064/api/frontend
```

## Configuration Files

- `docker-compose.yml`: Complete service stack definition
- `setup-test-flags.sh`: Database seeding script (1000 flags + segments)
- `run-wrk-test.sh`: Load testing orchestration
- `unleash-edge-test.lua`: wrk load testing scenarios
- `.env`: Environment variables for tokens and URLs

## Troubleshooting

### Frontend Edge Returns Empty Response

**Problem**: `curl http://localhost:3064/api/frontend` returns 0 features

**Solution**: Prime the frontend Edge:
```bash
curl -s "http://localhost:3064/api/client/features" \
  -H "Authorization: default:development.unleash-insecure-client-api-token" > /dev/null
```

### Container Health Issues

**Check container status:**
```bash
docker compose ps
docker logs unleash_tests-unleash-edge-frontend-1
```

**Restart specific service:**
```bash
docker compose restart unleash-edge-frontend
```

### Database Reset

If you need to start fresh:
```bash
# Stop and remove volumes
docker compose down -v

# Start fresh
docker compose up -d

# Re-seed database
./setup-test-flags.sh
```

## Performance Benchmarks

Based on local testing with 4 CPU cores:
- **Optimal performance**: ~1,500 req/s (2 threads, 10 connections)
- **Under stress**: ~1,335 req/s (12 threads, 100 connections)
- **Resource limits**: Performance degrades beyond 4 CPU cores

See `unleash-edge-capacity-consolidated.md` for production capacity planning.

## Production Considerations

### Scaling Requirements (300k concurrent users)

| Refresh Interval | Normal Instances | Peak Instances | Monthly Cost |
|------------------|------------------|----------------|--------------|
| 30 seconds ⭐     | 12               | 25             | $720-2,160   |
| 1 minute         | 6                | 12             | $432-1,296   |

### Architecture Recommendations

1. **Load balancer** with health checks
2. **Auto-scaling** based on request rate  
3. **Circuit breakers** for upstream failures
4. **CDN caching** for additional protection
5. **Monitoring** on throughput, latency, and error rates

### Edge Priming in Production

Add this to your deployment scripts:
```bash
# After Edge deployment, prime with client token
curl -s "$EDGE_URL/api/client/features" \
  -H "Authorization: $CLIENT_TOKEN" > /dev/null
```

## Development Tips

- **Feature flag cleanup**: Regularly remove unused flags to improve performance
- **Segment optimization**: Minimize complex segment rules  
- **Client-side caching**: Implement intelligent refresh logic in applications
- **Monitoring**: Track actual vs. estimated load patterns

## Support

- Unleash Documentation: https://docs.getunleash.io/
- Edge Documentation: https://docs.getunleash.io/reference/unleash-edge
- Load Testing: wrk documentation and examples