# CI/CD Setup for BMI Health Tracker

## Pipeline Architecture

- **Tool:** GitHub Actions
- **Triggers:** Push/PR to main branch folder spacific
- **Stages:**
  1. Checkout code
  2. Setup Node.js and cache dependencies
  3. Install dependencies
  4. Lint code
  5. Build application
  6. Run tests
  7. Build and push Docker image

## Monitoring Pipelines

- View runs at: https://github.com/mahmudunnabikajal/Ostad_devops-project-13.git
- Check logs for failures
- Secrets required: DOCKER_USERNAME, DOCKER_TOKEN
