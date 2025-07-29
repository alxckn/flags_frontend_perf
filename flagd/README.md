# Flagd Feature Flag Testing Environment

This repository contains a complete testing environment for flagd feature flag evaluation with HTTP configuration sync, including load testing tools and performance comparison with Unleash.

## Architecture

- **Nginx**: HTTP server serving flag configuration JSON at port 8080
- **Flagd**: Feature flag evaluation server consuming config via HTTP sync at port 8013

## Quick Start

### 1. Generate Configuration and Start Services

```bash
# Run the complete setup (generates config + starts services)
./setup-flagd-test.sh
```

**This will:**
- Generate 1000 test flags in flagd JSON format
- Start nginx reverse proxy serving the configuration
- Start flagd container with HTTP sync enabled
- Validate all services are working properly

**Services will be available at:**
- Nginx config server: http://localhost:8080/flags.json
- Flagd evaluation API: http://localhost:8013/ofrep/v1/evaluate/flags/{flag-key}
- Health checks: http://localhost:8080/health and http://localhost:8013/readyz

### 2. Run Load Tests

```bash
# Install wrk if needed
sudo apt install wrk

# Run comprehensive load test suite
./run-flagd-test.sh
```

**Test scenarios (same as Unleash for comparison):**
- Light Load: 2 threads, 10 connections, 30s
- Medium Load: 4 threads, 25 connections, 1min
- Heavy Load: 8 threads, 50 connections, 1min
- Stress Test: 12 threads, 100 connections, 30s

**User contexts tested:**
- EU Pro Desktop users (25% weight)
- US Patient Mobile users (30% weight)
- DE Pro Web users (25% weight)
- Basic context only (20% weight)

## Flag Configuration

The generated configuration mirrors the Unleash setup:

**Flag Distribution:**
- **300 flags (30%)**: Fully enabled
- **400 flags (40%)**: Segmented with random rollout percentages (10%, 25%, 50%, 75%, 90%)
- **300 flags (30%)**: Disabled

**Supported Contexts (Segments):**
- `tld`: fr, de, it (European users)
- `accountType`: pro, patient
- `platform`: mobile, desktop, web

## API Usage

### Flag Evaluation (OFREP Standard)

```bash
# Basic evaluation
curl -X POST http://localhost:8013/ofrep/v1/evaluate/flags/test-flag-0001 \
  -H "Content-Type: application/json" \
  -d '{"context": {"sessionId": "user123"}}'

# With user context for segmentation
curl -X POST http://localhost:8013/ofrep/v1/evaluate/flags/test-flag-0350 \
  -H "Content-Type: application/json" \
  -d '{
    "context": {
      "sessionId": "user123",
      "tld": "fr",
      "accountType": "pro", 
      "platform": "desktop"
    }
  }'
```

### Configuration Access

```bash
# View current flag configuration
curl http://localhost:8080/flags.json | jq .

# Check specific flag definition
curl http://localhost:8080/flags.json | jq '.flags["test-flag-0350"]'
```

## Configuration Files

- `docker-compose.yml`: Service stack with nginx and flagd
- `nginx.conf`: Nginx configuration for serving flags.json
- `generate-flagd-config.sh`: Script to generate 1000 test flags
- `setup-flagd-test.sh`: Complete setup orchestration
- `run-flagd-test.sh`: Load testing orchestration
- `flagd-test.lua`: wrk load testing scenarios

## Manual Setup (Alternative)

If you prefer manual steps:

```bash
# 1. Generate configuration
./generate-flagd-config.sh

# 2. Start services
docker compose up -d

# 3. Wait for services to be ready
curl http://localhost:8080/health
curl http://localhost:8013/readyz

# 4. Test evaluation
curl -X POST http://localhost:8013/ofrep/v1/evaluate/flags/test-flag-0001 \
  -H "Content-Type: application/json" \
  -d '{"context": {"sessionId": "test"}}'
```

## Monitoring

```bash
# Real-time container stats
docker stats

# Service logs
docker compose logs -f flagd
docker compose logs -f nginx

# Health checks
curl http://localhost:8013/readyz
curl http://localhost:8080/health
```

## Troubleshooting

### Flagd Not Starting

**Check logs:**
```bash
docker compose logs flagd
```

**Common issues:**
- Config server not accessible: ensure nginx is running first
- Invalid JSON: validate with `jq . flags.json`
- Port conflicts: check if ports 8013/8080 are available

### Configuration Sync Issues

**Test config endpoint:**
```bash
curl http://localhost:8080/flags.json | jq .
```

**Restart flagd to force sync:**
```bash
docker compose restart flagd
```

### Load Test Failures

**Check flagd health:**
```bash
curl http://localhost:8013/readyz
```

**Test evaluation manually:**
```bash
curl -X POST http://localhost:8013/ofrep/v1/evaluate/flags/test-flag-0001 \
  -H "Content-Type: application/json" \
  -d '{"context": {"sessionId": "test"}}'
```

## Performance Comparison with Unleash

This setup allows direct performance comparison with the Unleash Edge setup:

| Metric | Unleash Edge | Flagd |
|--------|-------------|-------|
| Architecture | Edge proxy + Unleash server | Direct evaluation |
| Sync Method | Server polling | HTTP config polling |
| API Standard | Unleash API | OFREP standard |
| Context Support | Native segments | JSONLogic targeting |

Run both test suites and compare:
- Request throughput (req/s)
- Response latency (ms)
- Resource usage (CPU/Memory)
- Error rates

## Cleanup

```bash
# Stop services and remove containers
docker compose down

# Remove generated configuration
rm -f flags.json

# Remove all data and start fresh
docker compose down -v
```

## Advanced Configuration

### Custom Flag Configuration

Edit `generate-flagd-config.sh` to modify:
- Flag count and distribution
- Targeting rules and contexts
- Rollout percentages
- Flag naming patterns

### Performance Tuning

Adjust in `docker-compose.yml`:
- `FLAGD_SYNC_PROVIDER_POLL_INTERVAL`: Config refresh frequency
- Resource limits (CPU/memory)
- Nginx cache headers in `nginx.conf`

### Load Test Customization

Modify `flagd-test.lua` for:
- Different user context distributions
- Custom flag evaluation patterns
- Additional performance metrics

## Support

- Flagd Documentation: https://flagd.dev/
- OFREP Standard: https://openfeature.dev/specification/flag-evaluation-api/
- Docker Compose: https://docs.docker.com/compose/