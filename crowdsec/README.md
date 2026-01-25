# DDoS Protection with CrowdSec

## Why CrowdSec?

After evaluating several open-source DDoS protection solutions, CrowdSec was chosen for this project because:

### 1. **Cloud-Native Architecture**
- Designed for modern containerized environments
- Works seamlessly with Kubernetes
- Lightweight agent with minimal resource overhead

### 2. **Collaborative Security**
- Shares threat intelligence across the CrowdSec community
- Benefits from collective IP reputation data
- Crowdsourced blocklists for known attackers

### 3. **Kong Integration**
- Native bouncer (enforcement) for Kong Gateway
- Real-time decision making
- No additional proxy layer needed

### 4. **Self-Managed / Open Source**
- Fully open-source (MIT License)
- No vendor lock-in
- Can run completely air-gapped if needed

### 5. **Multi-Layer Protection**
- L4 (network level) protection
- L7 (application level) protection
- Behavioral analysis and anomaly detection

## Architecture

```
                         ┌─────────────────────────────────────┐
                         │         CrowdSec Console           │
                         │    (Central Intelligence Hub)       │
                         └─────────────────┬───────────────────┘
                                          │ Threat Intel
                                          ▼
┌──────────────┐        ┌─────────────────────────────────────┐
│   Client     │───────▶│           Kong Gateway              │
│   Request    │        │   ┌─────────────────────────────┐   │
└──────────────┘        │   │   CrowdSec Bouncer Plugin   │   │
                        │   └──────────────┬──────────────┘   │
                        └──────────────────┼──────────────────┘
                                          │
                                          ▼
                        ┌─────────────────────────────────────┐
                        │        CrowdSec Agent (LAPI)        │
                        │   ┌─────────────────────────────┐   │
                        │   │     Scenario Detection      │   │
                        │   │ • HTTP Flood Detection      │   │
                        │   │ • Brute Force Detection     │   │
                        │   │ • Crawl Detection           │   │
                        │   │ • Custom Scenarios          │   │
                        │   └─────────────────────────────┘   │
                        └─────────────────────────────────────┘
```

## Components

### 1. CrowdSec Agent (Security Engine)
- Reads logs from Kong
- Applies detection scenarios
- Makes ban/allow decisions
- Syncs with CrowdSec Central API

### 2. CrowdSec Local API (LAPI)
- Stores decisions locally
- Serves decisions to bouncers
- Manages machine registrations

### 3. Kong Bouncer
- Enforces decisions at the gateway
- Blocks banned IPs
- Minimal latency impact

## Protection Scenarios

The following scenarios are enabled:

1. **HTTP Flood Protection**
   - Detects abnormally high request rates
   - Automatic ban for offending IPs

2. **Brute Force Protection**
   - Monitors login attempts
   - Bans after multiple failures

3. **Crawl/Scan Detection**
   - Identifies web scanners
   - Blocks reconnaissance attempts

4. **Custom Scenarios**
   - Can be extended with custom rules
   - YAML-based configuration

## Testing DDoS Protection

### Test Rate-Based Ban

```bash
# Generate rapid requests to trigger detection
for i in {1..100}; do
  curl -s http://kong-gateway/health &
done
wait

# Check if IP was banned
curl http://kong-gateway/health
# Should return 403 if banned
```

### Check CrowdSec Decisions

```bash
# Inside CrowdSec pod
kubectl exec -it crowdsec-0 -n api-platform -- cscli decisions list
```

### View Metrics

```bash
kubectl exec -it crowdsec-0 -n api-platform -- cscli metrics
```

## Configuration Files

- `crowdsec-deployment.yaml`: Kubernetes deployment
- `acquis.yaml`: Log acquisition configuration
- `profiles.yaml`: Decision profiles
- `scenarios/`: Custom detection scenarios

