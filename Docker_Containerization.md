# Docker Containerization for BMI Health Tracker

## Overview

This phase containerizes the BMI Health Tracker application using Docker, creating production-ready images for both frontend and backend services.

## Dockerfile Structure

### Frontend Dockerfile (Multi-stage)

- **Build Stage:** Node.js 18 Alpine - builds React app with Vite
- **Runtime Stage:** Nginx Alpine - serves static files with minimal image size
- **Benefits:**
  - Smaller production image (only Nginx, no Node.js)
  - Build dependencies excluded from final image
  - Fast deployments

### Backend Dockerfile

- **Base:** Node.js 18 Alpine
- **Install:** Production dependencies only
- **Expose:** Port 3000 for Express API

## .dockerignore Files

Excludes unnecessary files from Docker build context:

**Frontend:**

- Build artifacts (unless needed)
- Tests, linting configs
- Development dependencies metadata
- Git files

**Backend:**

- Tests, migrations, configs
- Development files
- Environment files (.env)
- Git files

## Docker Compose

Local development setup with three services:

1. **Frontend** - Nginx on port 80
2. **Backend** - Express on port 3000
3. **Database** - PostgreSQL on port 5432

### Running Locally

```bash
docker-compose up -d
# Access frontend at http://localhost
# Access backend API at http://localhost:3000/api
# Database at localhost:5432
```

## CI/CD Integration

Both frontend and backend workflows now include Docker build and push:

1. **Build:** `docker build -t image:SHA .`
2. **Tag:** Latest tag for convenience
3. **Login:** Docker Hub authentication with DOCKER_TOKEN
4. **Push:** Both SHA-tagged and latest versions

### Triggering Builds

- Frontend builds on changes to `app/frontend/**`
- Backend builds on changes to `app/backend/**`
- Only pushes on main branch (not on PRs)

## Image Naming

- Frontend: `mahmudunnabikajal/bmi-frontend:SHA` and `:latest`
- Backend: `mahmudunnabikajal/bmi-backend:SHA` and `:latest`

## Next Steps

- Monitor Docker Hub for successful pushes
- Pull images for deployment to Kubernetes (Phase 3)
- Set up automated cleanup for old images
