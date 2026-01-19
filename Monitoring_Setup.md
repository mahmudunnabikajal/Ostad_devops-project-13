# Phase 5: Monitoring Tools (Prometheus, Loki, Grafana)

## Overview

Comprehensive monitoring solution for observing application health and infrastructure performance.

**Components**:

- **Prometheus**: Metrics collection and alerting
- **Loki**: Log aggregation
- **Grafana**: Dashboards and visualization
- **Alertmanager**: Alert routing and management
- **Promtail**: Log shipping to Loki

---

## Prometheus Deployment

### Purpose

Scrapes metrics from:

- Backend service
- Frontend service
- PostgreSQL database
- Redis cache
- Kubernetes nodes and pods

### Files

- `kubernetes/monitoring/prometheus/deployment.yaml`
- `kubernetes/monitoring/prometheus/configmap.yaml`
- `kubernetes/monitoring/prometheus/rules/alert-rules.yaml`

### Configuration

Prometheus configuration includes:

- 15-second scrape interval
- 15-day data retention
- Kubernetes service discovery
- Alert rule evaluation
- Alertmanager integration

### Metrics Collected

**Application Metrics**:

- HTTP request rate
- HTTP request duration
- Error rates by status code

**Infrastructure Metrics**:

- Node CPU and memory usage
- Pod restart rates
- Kubernetes API server metrics

**Database Metrics**:

- PostgreSQL connections and query rate
- Redis memory and command rate

---

## Loki Deployment

### Purpose

Aggregates logs from all pods in the cluster.

### Files

- `kubernetes/monitoring/loki/configmap.yaml`
- `kubernetes/monitoring/loki/deployment.yaml`

### Components

**Loki**:

- Stores logs in filesystem
- Exposes API on port 3100
- Retention: 168 hours

**Promtail** (DaemonSet):

- Runs on every node
- Collects logs from `/var/log` and Docker containers
- Sends to Loki via push API
- Labels pods with metadata

### Log Labels

Logs are labeled with:

- Namespace
- Pod name
- Container name
- Application label
- Node name

---

## Grafana Dashboards

### Purpose

Visualize metrics and logs from Prometheus and Loki.

### Files

- `kubernetes/monitoring/grafana/deployment.yaml`
- `kubernetes/monitoring/grafana/configmap.yaml`
- `kubernetes/monitoring/grafana/dashboards/application-dashboard.json`
- `kubernetes/monitoring/grafana/dashboards/kubernetes-dashboard.json`
- `kubernetes/monitoring/grafana/dashboards/redis-dashboard.json`
- `kubernetes/monitoring/grafana/dashboards/postgresql-dashboard.json`

### Dashboards

**Application Dashboard**:

- Backend request rate
- Backend error rate
- Backend P95 response time
- Service status

**Kubernetes Dashboard**:

- Node CPU and memory usage
- Nodes ready count
- Pods running count
- Pod restart rate

**Redis Dashboard**:

- Network I/O rate
- Memory usage
- Commands per second
- Connected clients

**PostgreSQL Dashboard**:

- Active connections
- Database size
- Query rate
- Slow query times

### Access

- **URL**: `http://<node-ip>:31000`
- **Default Credentials**: admin / admin
- **Port**: 31000 (NodePort)

---

## Alert Rules

### File

`kubernetes/monitoring/prometheus/rules/alert-rules.yaml`

### Alert Categories

**Backend Alerts**:

- Service down (critical)
- High error rate > 5% (warning)
- High response time > 1s (warning)

**Database Alerts**:

- PostgreSQL down (critical)
- High connection count > 90 (warning)
- Slow queries detected (warning)

**Cache Alerts**:

- Redis down (critical)
- High memory usage > 90% (warning)

**Kubernetes Alerts**:

- Pod crash looping (warning)
- Pod not healthy (warning)
- Node not ready (critical)
- Node high CPU > 80% (warning)
- Node high memory > 85% (warning)
- Low disk space < 10% (warning)

### Evaluation

- Evaluation interval: 15 seconds
- Evaluation duration: Specified per rule
- Alertmanager targets: alertmanager:9093

---

## Alertmanager Configuration

### File

`kubernetes/monitoring/alertmanager/configmap.yaml`

### Alert Routing

**Critical Alerts**:

- Channel: #critical-alerts
- Wait time: 0 seconds
- Repeat interval: 5 minutes

**Warning Alerts**:

- Channel: #warnings
- Wait time: 30 seconds
- Repeat interval: 5 minutes

### Configuration Steps

1. Update `alertmanager-config` ConfigMap with Slack webhook URL
2. Create Slack channels: `#critical-alerts`, `#warnings`, `#monitoring`
3. Restart alertmanager to apply changes

### Update Webhook URL

File: `kubernetes/monitoring/alertmanager/configmap.yaml`

Replace: `YOUR_SLACK_WEBHOOK_URL` with actual Slack webhook

Restart: `kubectl rollout restart deployment/alertmanager -n monitoring`

---

## Deployment Instructions

### Step 1: Create Monitoring Namespace

Apply: `kubernetes/monitoring/namespace.yaml`

### Step 2: Deploy Prometheus

Files to apply:

- `kubernetes/monitoring/prometheus/configmap.yaml`
- `kubernetes/monitoring/prometheus/rules/alert-rules.yaml`
- `kubernetes/monitoring/prometheus/deployment.yaml`

Verify: `kubectl get pods -n monitoring | grep prometheus`

### Step 3: Deploy Loki

Files to apply:

- `kubernetes/monitoring/loki/configmap.yaml`
- `kubernetes/monitoring/loki/deployment.yaml`

Verify: `kubectl get pods -n monitoring | grep loki` and `kubectl get ds -n monitoring | grep promtail`

### Step 4: Deploy Grafana

Files to apply:

- `kubernetes/monitoring/grafana/configmap.yaml`
- `kubernetes/monitoring/grafana/dashboards-configmap.yaml`
- `kubernetes/monitoring/grafana/deployment.yaml`

Verify: `kubectl get pods -n monitoring | grep grafana`

### Step 5: Deploy Alertmanager

Files to apply:

- `kubernetes/monitoring/alertmanager/configmap.yaml`
- `kubernetes/monitoring/alertmanager/deployment.yaml`

Verify: `kubectl get pods -n monitoring | grep alertmanager`

### Deploy All Components

Command: `kubectl apply -f kubernetes/monitoring/`

Verify all pods are running: `kubectl get pods -n monitoring`

---

## Accessing Dashboards

### Prometheus

- **URL**: `http://<node-ip>:30090`
- **Purpose**: View metrics, test queries, debug scrapes
- **Port**: 30090 (NodePort)

### Grafana

- **URL**: `http://<node-ip>:31000`
- **Credentials**: admin / admin
- **Port**: 31000 (NodePort)

### Alertmanager

- **URL**: `http://<node-ip>:30093`
- **Port**: 30093 (NodePort)
- **View**: Active alerts, alert history

---

## Metrics Collection

### Data Flow

1. **Prometheus** scrapes metrics from endpoints
2. **Promtail** collects logs from nodes
3. **Loki** stores and indexes logs
4. **Grafana** queries Prometheus and Loki
5. **Alertmanager** receives and routes alerts

### Data Retention

- **Prometheus**: 15 days
- **Loki**: 7 days (168 hours)
- **Grafana**: Real-time queries, no retention

### Storage

- **Prometheus**: `emptyDir` (ephemeral)
- **Loki**: `emptyDir` (ephemeral)
- **Grafana**: `emptyDir` (ephemeral)

**Note**: For production, use persistent volumes (PVC).

---

## Troubleshooting

### Prometheus Not Scraping Metrics

1. Check configuration: View Prometheus targets at `/targets`
2. Verify service discovery: Check for pod annotations
3. Review logs: `kubectl logs -n monitoring deployment/prometheus`

### Loki Not Receiving Logs

1. Verify Promtail is running: `kubectl get ds -n monitoring promtail`
2. Check Promtail logs: `kubectl logs -n monitoring ds/promtail`
3. Verify Loki connectivity: `telnet loki 3100` from pod

### Grafana Dashboard Empty

1. Verify datasources are configured: Settings > Data Sources
2. Check Prometheus connectivity: Test datasource
3. Review dashboard queries: Edit panel and test query

### Alerts Not Firing

1. Check alert rules: View Prometheus `/rules`
2. Verify alert status: Check Alertmanager `/alerts`
3. Review logs: `kubectl logs -n monitoring deployment/alertmanager`

---

## Advanced Configuration

### Adding Custom Metrics

1. Enable prometheus.io annotations on pods
2. Update Prometheus scrape config to include annotation-based discovery
3. Restart Prometheus

### Adding Custom Dashboards

1. Create dashboard JSON in `grafana/dashboards/`
2. Update Grafana ConfigMap with dashboard file
3. Restart Grafana to load new dashboards

### Enabling Persistent Storage

Replace `emptyDir` with `persistentVolumeClaim` in deployments:

- Create PVC for each component
- Reference PVC in volume mounts
- Retain data across pod restarts

### High Availability

For production:

- Deploy 3+ Prometheus replicas with Remote Storage
- Deploy 3+ Loki instances with object storage backend
- Deploy 3+ Grafana instances with shared database
- Configure Alertmanager clustering

---

## Best Practices

1. **Always** use persistent volumes in production
2. **Set** appropriate resource limits to prevent node eviction
3. **Monitor** the monitors: Set up alerts for Prometheus/Loki itself
4. **Regular** backups of dashboards and rules
5. **Review** retention policies based on storage capacity
6. **Secure** Grafana with strong passwords and RBAC
7. **Test** alert rules with synthetic metrics before production

---

## Summary

**Prometheus**: Metrics collection → 15-second interval → 15-day retention

**Loki**: Log aggregation → Real-time ingestion → 7-day retention

**Grafana**: Dashboard visualization → Datasource configuration → Multiple dashboards

**Alertmanager**: Alert routing → Slack integration → Critical/Warning channels

**Promtail**: Log shipping → Node-level DaemonSet → Metadata labeling

All components accessible via NodePort for testing and debugging.
