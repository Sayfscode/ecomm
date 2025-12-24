# React Application Deployment with CI/CD and Monitoring

This project demonstrates deploying a React application into a production-ready environment using Docker, Jenkins CI/CD, AWS EC2, and lightweight open-source monitoring.

---

## Application Overview
- Frontend: React
- Web Server: Nginx
- Containerization: Docker
- CI/CD Tool: Jenkins
- Cloud Provider: AWS EC2 (t2.micro)

---

## Repository & Deployment

- **GitHub Repository**: https://github.com/<your-username>/<repo-name>
- **Deployed Application URL**: http://51.21.202.252/login
- **Jenkins URL**: http://51.21.202.252:8080

---

## Docker Images

- **Dev Image**: `<dockerhub-username>/dev:latest`
- **Prod Image**: `<dockerhub-username>/prod:latest` (Private)

Docker images are built and pushed automatically via Jenkins:
- Push to `dev` branch → dev Docker Hub repo
- Merge to `master` branch → prod Docker Hub repo

---

## CI/CD Pipeline (Jenkins)

The Jenkins pipeline performs:
1. Source code checkout from GitHub
2. Docker image build
3. Push image to Docker Hub
4. Deployment to AWS EC2 (master branch)

Screenshots:
- Jenkins login page
- Job configuration
- Pipeline console output  
(Available in `screenshots/jenkins/`)

---

## AWS Infrastructure

- EC2 Instance: t2.micro (Ubuntu)
- Security Group Rules:
  - Port 80: Open to public (Application access)
  - Port 22: Restricted to personal IP (SSH)
  - Port 8080: Restricted to personal IP (Jenkins)

Screenshots available in `screenshots/aws/`.

---

## Monitoring

Application health monitoring is implemented using open-source Linux tools:

- HTTP health check using `curl`
- Bash script execution
- Status based on HTTP response codes (2xx/3xx = UP)
- Docker logs used for runtime visibility

Example output:

APP STATUS: UP (HTTP 200)
Monitoring screenshots are available in `screenshots/monitoring/`.

---

## Logs

- Application logs: `docker logs <container_name>`
- Nginx access logs captured via Docker stdout

---

## Screenshots Included

All required screenshots are included:
- Jenkins dashboard, job config, console output
- AWS EC2 instance & security group
- Docker Hub dev & prod repositories
- Deployed application page
- Monitoring health check status

---

## Conclusion

This project showcases a complete DevOps workflow including CI/CD automation, containerized deployment, cloud infrastructure setup, and application health monitoring using open-source tools.
