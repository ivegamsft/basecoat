# Basecoat Portal Staging - Network Architecture

## VPC Topology

### Address Space Allocation

\\\
VPC CIDR Block: 10.0.0.0/16 (65,536 IP addresses)

├── Public Subnets (ALB Tier)
│   ├── Public Subnet AZ1: 10.0.10.0/24 (256 IPs)
│   │   └── Route: 0.0.0.0/0 → Internet Gateway
│   └── Public Subnet AZ2: 10.0.11.0/24 (256 IPs)
│       └── Route: 0.0.0.0/0 → Internet Gateway
│
├── Private Subnets (Application Tier)
│   ├── Private Subnet AZ1: 10.0.1.0/24 (256 IPs)
│   │   └── Route: 0.0.0.0/0 → NAT Gateway AZ1
│   └── Private Subnet AZ2: 10.0.2.0/24 (256 IPs)
│       └── Route: 0.0.0.0/0 → NAT Gateway AZ2
│
└── Private Subnets (Database Tier)
    ├── Private Subnet AZ1: 10.0.3.0/24 (256 IPs)
    │   └── Route: None (RDS doesn't route outbound)
    └── Private Subnet AZ2: 10.0.4.0/24 (256 IPs)
        └── Route: None (RDS doesn't route outbound)

Reserved: 10.0.5.0/24 - 10.0.9.0/24 (future expansion)
\\\

---

## Network Diagram (ASCII)

\\\
┌─────────────────────────────────────────────────────────────┐
│                        INTERNET                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                    [WAF / DDoS]
                         │
                         ▼
            ┌────────────────────────┐
            │  Internet Gateway      │
            │  (IGW)                 │
            └────────────┬───────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
    ┌──────────┐  ┌──────────┐    ┌────────────┐
    │  ALB SG  │  │  EIP #1  │    │  EIP #2   │
    │Allow:    │  │(NAT Gateway AZ1)│(NAT Gateway AZ2)
    │  80/443  │  │          │    │           │
    └────┬─────┘  └────┬─────┘    └─────┬─────┘
         │             │                │
    ┌────▼─────────────▼────────────────▼────┐
    │         Public Tier (AZ1 & AZ2)        │
    │  ┌─────────────────────────────────┐   │
    │  │ Public Subnets                  │   │
    │  │ 10.0.10.0/24  │  10.0.11.0/24 │   │
    │  │ (ALB deployed)│  (ALB deployed)    │   │
    │  └────────┬──────────────┬────────┘   │
    │           │              │             │
    │  ┌────────▼──────────────▼────────┐   │
    │  │ Target Group Health Checks     │   │
    │  │ (Instance ports 80/443)        │   │
    │  └────────┬──────────────┬────────┘   │
    └───────────┼──────────────┼─────────────┘
                │              │
                ▼              ▼
    ┌───────────────────────────────────┐
    │   Application Tier (Private)      │
    │   ┌──────────────────────────────┐│
    │   │ App SG - Allow:              ││
    │   │  • From ALB SG: 80/443       ││
    │   │  • From Cache SG: 6379       ││
    │   │  • From DB SG: 5432 (reply)  ││
    │   │  • To Cache SG: 6379         ││
    │   │  • To DB SG: 5432            ││
    │   │  • To 0.0.0.0/0: 443 (HTTPS) ││
    │   └────────────┬─────────────────┘│
    │               │                   │
    │   ┌───────────┼────────────────┐  │
    │   │ Private Subnets            │  │
    │   │ 10.0.1.0/24  │ 10.0.2.0/24│  │
    │   │ (EC2 App)    │ (EC2 App)  │  │
    │   └───────────┬────────────────┘  │
    │               │                   │
    └───────────────┼───────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
    ┌─────────────────────────────────┐
    │    Data Tier (Private)          │
    │  ┌────────────────────────────┐ │
    │  │ Database SG - Allow:       │ │
    │  │  • From App SG: 5432       │ │
    │  │  • No outbound required    │ │
    │  └────────┬───────────────────┘ │
    │           │                     │
    │  ┌────────▼───────────────────┐ │
    │  │ Private Subnets (DB Tier)  │ │
    │  │ 10.0.3.0/24 (AZ1)          │ │
    │  │ 10.0.4.0/24 (AZ2)          │ │
    │  └────────┬───────────────────┘ │
    │           │                     │
    │  ┌────────▼───────────────────┐ │
    │  │ RDS PostgreSQL Multi-AZ    │ │
    │  │ Primary (AZ1) - Active     │ │
    │  │ Standby (AZ2) - Replica    │ │
    │  └────────────────────────────┘ │
    └─────────────────────────────────┘
                    │
        ┌───────────┴──────────────────┐
        │                              │
        ▼                              ▼
    ┌──────────────────────┐  ┌────────────────────────┐
    │  Cache Tier          │  │ Monitoring & Logging   │
    │  ┌────────────────┐  │  │ ┌────────────────────┐ │
    │  │ Cache SG       │  │  │ │ CloudWatch Logs    │ │
    │  │  • From App:   │  │  │ │ • VPC Flow Logs    │ │
    │  │    6379        │  │  │ │ • RDS Logs         │ │
    │  └────────┬───────┘  │  │ │ • Cache Logs       │ │
    │           │          │  │ │ • Application Logs │ │
    │  ┌────────▼───────┐  │  │ └────────────────────┘ │
    │  │ ElastiCache    │  │  │ ┌────────────────────┐ │
    │  │ Redis Cluster  │  │  │ │ CloudWatch Alarms  │ │
    │  │ (2 nodes, HA)  │  │  │ │ • RDS CPU >80%     │ │
    │  │ Node 1 (AZ1)   │  │  │ │ • Cache Mem >80%   │ │
    │  │ Node 2 (AZ2)   │  │  │ │ • ALB Error >1%    │ │
    │  └────────────────┘  │  │ └────────────────────┘ │
    └──────────────────────┘  └────────────────────────┘
\\\

---

## Network Flow Examples

### Example 1: User Request to Application

\\\
1. Client Request
   Client → (HTTPS/443) → ALB DNS

2. ALB Processing
   ALB (Public Subnets) → (HTTP/80 or 443) → 
   Target Group (Health check: /health)

3. Application Processing
   EC2 Instance (Private Subnet) →
   Accepts request on port 80/443 →
   Processes request

4. Database Query
   EC2 → (5432 via App SG → DB SG) →
   RDS (Private DB Subnet)

5. Cache Operation
   EC2 → (6379 via App SG → Cache SG) →
   ElastiCache (Private Data Subnet)

6. Response
   EC2 → ALB → (HTTPS/443) → Client
\\\

### Example 2: Outbound Internet Access

\\\
1. EC2 Instance (10.0.1.x)
   Initiates outbound request (e.g., NPM package download)

2. Route Table (Private Subnet)
   Destination: 0.0.0.0/0 → NAT Gateway

3. NAT Gateway (10.0.10.x public subnet)
   Translates source IP to Elastic IP
   Sends request to Internet

4. Response
   NAT Gateway ← Response from Internet
   Translates back to EC2 private IP
   Routes to EC2 instance

5. EC2 receives response
   All appears to come from EC2's perspective
   Internet sees request from NAT Gateway EIP
\\\

---

## Route Tables

### Public Route Table (ALB Tier)

| Destination | Target | Status |
|-------------|--------|--------|
| 10.0.0.0/16 | Local | Active |
| 0.0.0.0/0 | Internet Gateway | Active |

**Subnets Associated**: 
- 10.0.10.0/24 (Public AZ1)
- 10.0.11.0/24 (Public AZ2)

### Private Route Table AZ1 (App Tier)

| Destination | Target | Status |
|-------------|--------|--------|
| 10.0.0.0/16 | Local | Active |
| 0.0.0.0/0 | NAT Gateway (AZ1) | Active |

**Subnets Associated**:
- 10.0.1.0/24 (Private App AZ1)

### Private Route Table AZ2 (App Tier)

| Destination | Target | Status |
|-------------|--------|--------|
| 10.0.0.0/16 | Local | Active |
| 0.0.0.0/0 | NAT Gateway (AZ2) | Active |

**Subnets Associated**:
- 10.0.2.0/24 (Private App AZ2)

### Database Route Table (Data Tier)

| Destination | Target | Status |
|-------------|--------|--------|
| 10.0.0.0/16 | Local | Active |

**Subnets Associated**:
- 10.0.3.0/24 (Private DB AZ1)
- 10.0.4.0/24 (Private DB AZ2)

**Note**: No outbound route for RDS - traffic stays within VPC

---

## Network ACLs (Default)

All subnets use default Network ACLs:

| Rule # | Type | Protocol | Port | CIDR | Action |
|--------|------|----------|------|------|--------|
| 100 | Inbound | All | All | 0.0.0.0/0 | ALLOW |
| 110 | Outbound | All | All | 0.0.0.0/0 | ALLOW |

**Note**: Security Groups provide firewall control; NACLs are permissive

---

## DNS & Service Discovery

### Internal DNS (VPC)

Enabled: DNS hostnames and DNS support

**Service Discovery**:
- RDS: basecoat-portal-db.XXXXXXXXXXXX.us-east-1.rds.amazonaws.com
- ElastiCache: basecoat-portal-redis.XXXXXXXXXXXX.ng.0001.use1.cache.amazonaws.com
- ALB: basecoat-portal-alb-XXXXXXXXXXXX.us-east-1.elb.amazonaws.com

### VPC Flow Logs

Captured for all traffic:
- Source/destination IP
- Source/destination port
- Protocol
- Bytes/packets
- Accept/Reject status

**Destination**: CloudWatch Logs (/aws/vpc/flow-logs/basecoat-portal)

---

## High Availability & Failover

### ALB Multi-AZ

- ALB instances in Public Subnets (AZ1, AZ2)
- Automatic failover if AZ goes down
- Health checks on target instances (port 80/443)
- Unhealthy instances automatically removed

### RDS Multi-AZ

- Primary in Private DB Subnet AZ1
- Standby replica in Private DB Subnet AZ2
- Synchronous replication
- Automatic failover (60-120 seconds)
- Connection string always points to primary

### ElastiCache Multi-AZ

- Primary node in Private Data Subnet AZ1
- Replica node in Private Data Subnet AZ2
- Automatic failover enabled
- Both nodes accessible via reader endpoint

### NAT Gateway Redundancy

- NAT Gateway 1 in Public Subnet AZ1
- NAT Gateway 2 in Public Subnet AZ2
- Route tables per AZ use local NAT gateway
- Failure of one NAT doesn't affect other AZ

---

## Network Bandwidth Allocation

### Estimated Network Usage (Staging)

| Traffic Type | Direction | Estimated Volume | Requirement |
|--------------|-----------|------------------|-------------|
| ALB → App | Inbound | 10-50 Mbps | 1 Gbps connection |
| App → RDS | Bidirectional | 5-20 Mbps | VPC throughput |
| App → Cache | Bidirectional | 1-10 Mbps | VPC throughput |
| Outbound (NAT) | Outbound | 1-5 Mbps | NAT bandwidth |
| VPC Flow Logs | Logging | <1 Mbps | CloudWatch Logs |

**Total Estimated**: 15-85 Mbps (well within AWS limits)

---

## Network Monitoring

### CloudWatch Metrics

Monitor via CloudWatch dashboards:

\\\ash
# VPC Flow Log metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/VPC \
  --metric-name BytesIn \
  --dimensions Name=NetworkInterface,Value=<eni-id> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average,Sum

# ALB Network Metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name ProcessedBytes \
  --dimensions Name=LoadBalancer,Value=app/basecoat-portal-alb/<id> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Sum
\\\

---

## Scaling Topology for Production

### Production Enhancements

1. **Additional Regions**: Deploy secondary region (us-west-2) for DR
2. **Route 53**: Global load balancing across regions
3. **VPC Peering**: Connect multiple VPCs if needed
4. **Transit Gateway**: Centralized network hub for multi-region
5. **AWS Global Accelerator**: Optimize routing for global users
6. **Enhanced NAT**: Gateway Load Balancer for higher throughput

---

**Document Version**: 1.0
**Last Updated**: 2024
