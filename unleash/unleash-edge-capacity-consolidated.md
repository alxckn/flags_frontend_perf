# Unleash Edge Capacity Planning - Consolidated

**Context**: 300,000 concurrent users, 1,400 req/s per Edge instance (4 CPU cores), 700 feature flags

| Refresh Interval | Sustained Load (req/s) | Normal Instances | Peak Instances | Incident Instances* | Monthly Cost Range |
|------------------|------------------------|------------------|----------------|--------------------|--------------------|
| **10 seconds**   | 30,000                 | 30               | 60             | 250                | $2,160 - $6,120    |
| **30 seconds** ⭐ | 10,000                 | 12               | 25             | 250                | $720 - $2,160      |
| **1 minute**     | 5,000                  | 6                | 12             | 250                | $432 - $1,296      |
| **1 minute 30s** | 3,333                  | 4                | 8              | 250                | $360 - $864        |

**Column Definitions:**
- **Normal Instances**: Recommended for sustained daily operations (with safety margin)
- **Peak Instances**: Auto-scaling capacity for traffic spikes (2-3x normal load)  
- **Incident Instances**: Cold start scenario (all users refresh simultaneously)*
- **Monthly Cost**: Based on $0.10/hour per 4-core instance, normal to peak scaling

**Notes:**
- *Incident scenarios (250 instances) require architectural solutions beyond scaling (circuit breakers, CDN, queuing)
- ⭐ **30-second refresh recommended** for optimal cost/performance balance
- Peak instances assume 2-3x traffic during high-usage periods
- Costs calculated for continuous operation (normal) to auto-scaling (peak)