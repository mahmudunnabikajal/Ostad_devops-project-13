# Kubernetes Architecture for BMI Health Tracker

## Overview

Production-ready Kubernetes deployment for the BMI Health Tracker application with automatic scaling, health checks, and persistent storage.

## Archetecture Diagram

![Archetecture Diagram](./images/phase-3-architecture-diagram.jpg)

## Kubernetes Objects

### Namespace

- `bmi-health-tracker` - Isolates all resources

### Secrets

- `db-credentials` - Base64 encoded database credentials
  - username: `bmi_user`
  - password: `strongpassword`
  - database: `bmidb`
  - db-url: Full PostgreSQL connection string

### Frontend Deployment

- **Replicas:** 2
- **Image:** `mahmudunnabikajal/bmi-frontend:latest`
- **Port:** 80 (Nginx)
- **Resource Requests:**
  - CPU: 100m | Memory: 128Mi
- **Resource Limits:**
  - CPU: 200m | Memory: 256Mi
- **Health Checks:**
  - Liveness: HTTP GET `/` every 10s
  - Readiness: HTTP GET `/` every 5s
- **Service:** ClusterIP (internal only)

### Backend Deployment

- **Replicas:** 2
- **Image:** `mahmudunnabikajal/bmi-backend:latest`
- **Port:** 3000 (Express API)
- **Environment:**
  - `NODE_ENV=production`
  - `DATABASE_URL` from Secret
- **Resource Requests:**
  - CPU: 200m | Memory: 256Mi
- **Resource Limits:**
  - CPU: 500m | Memory: 512Mi
- **Health Checks:**
  - Liveness: HTTP GET `/health` every 10s
  - Readiness: HTTP GET `/health` every 5s
- **Service:** ClusterIP (internal only)

### PostgreSQL StatefulSet

- **Replicas:** 1
- **Image:** `postgres:12-alpine`
- **Port:** 5432
- **Persistent Volume:**
  - Size: 10Gi
  - Mount Path: `/var/lib/postgresql/data`
- **Resource Requests:**
  - CPU: 200m | Memory: 512Mi
- **Resource Limits:**
  - CPU: 500m | Memory: 1Gi
- **Service:** Headless (clusterIP: None) for StatefulSet DNS

### Redis Deployment

- **Replicas:** 1
- **Image:** `redis:7-alpine`
- **Port:** 6379
- **Persistent Volume:**
  - Size: 2Gi
  - Mount Path: `/data`
- **Resource Requests:**
  - CPU: 100m | Memory: 128Mi
- **Resource Limits:**
  - CPU: 200m | Memory: 256Mi
- **Health Checks:**
  - Liveness: TCP socket check on 6379
  - Readiness: `redis-cli ping` command
- **Service:** ClusterIP (internal only)

### Ingress

- **Host:** `bmi.example.com` (update with your domain)
- **Routes:**
  - `/` → frontend-service:80
  - `/api` → backend-service:3000

## Deployment Instructions

### 1. Create namespace and secrets

```bash
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/secrets.yaml
```

### 2. Deploy PostgreSQL

```bash
kubectl apply -f kubernetes/postgresql.yaml
# Wait for PostgreSQL to be ready
kubectl rollout status statefulset/postgresql -n bmi-health-tracker
```

### 3. Deploy Redis

```bash
kubectl apply -f kubernetes/redis.yaml
# Wait for Redis to be ready
kubectl rollout status deployment/redis -n bmi-health-tracker
```

### 4. Deploy backend

```bash
kubectl apply -f kubernetes/backend.yaml
# Wait for backend deployment
kubectl rollout status deployment/backend -n bmi-health-tracker
```

### 5. Deploy frontend

```bash
kubectl apply -f kubernetes/frontend.yaml
# Wait for frontend deployment
kubectl rollout status deployment/frontend -n bmi-health-tracker
```

### 6. Deploy ingress

```bash
kubectl apply -f kubernetes/ingress.yaml
```

### 7. Verify deployment

```bash
# Check all pods
kubectl get pods -n bmi-health-tracker

# Check services
kubectl get svc -n bmi-health-tracker

# Check ingress
kubectl get ingress -n bmi-health-tracker

# View logs
kubectl logs -f deployment/backend -n bmi-health-tracker
kubectl logs -f deployment/frontend -n bmi-health-tracker
```

## Access Application

1. Update your hosts file or DNS:

   ```
   YOUR_CLUSTER_IP  bmi.example.com
   ```

2. Access the app:
   - Frontend: http://bmi.example.com
   - Backend API: http://bmi.example.com/api

## Scaling

### Manual Scaling

```bash
# Scale frontend to 5 replicas
kubectl scale deployment frontend --replicas=5 -n bmi-health-tracker

# Scale backend to 3 replicas
kubectl scale deployment backend --replicas=3 -n bmi-health-tracker
```

## Monitoring & Debugging

### Pod Status

```bash
kubectl get pods -n bmi-health-tracker -w
```

### Pod Events

```bash
kubectl describe pod <pod-name> -n bmi-health-tracker
```

### Container Logs

```bash
kubectl logs <pod-name> -n bmi-health-tracker
kubectl logs <pod-name> -c <container-name> -n bmi-health-tracker --tail=50 -f
```

### Port Forward for Local Access

```bash
# Frontend
kubectl port-forward svc/frontend-service 8080:80 -n bmi-health-tracker

# Backend
kubectl port-forward svc/backend-service 3000:3000 -n bmi-health-tracker

# PostgreSQL
kubectl port-forward svc/postgresql-service 5432:5432 -n bmi-health-tracker

# Redis
kubectl port-forward svc/redis-service 6379:6379 -n bmi-health-tracker
```

## Storage & Backup

### View PVC

```bash
kubectl get pvc -n bmi-health-tracker
```

### Backup PostgreSQL

```bash
kubectl exec -it postgresql-0 -n bmi-health-tracker -- \
  pg_dump -U bmi_user -d bmidb > backup.sql
```

### Restore PostgreSQL

```bash
kubectl exec -i postgresql-0 -n bmi-health-tracker -- \
  psql -U bmi_user -d bmidb < backup.sql
```

## Cleanup

```bash
# Delete all resources in namespace
kubectl delete namespace bmi-health-tracker
```
