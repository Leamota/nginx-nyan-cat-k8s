# Containerized NGINX Nyan Cat Website

## Overview

This project demonstrates the deployment of a containerized NGINX web server hosting an embedded Nyan Cat video. The application was built using a GitLab CI/CD pipeline with Kaniko and deployed to a Kubernetes cluster through Rancher.

## Technologies Used

- NGINX
- Docker
- GitLab CI/CD
- Kaniko
- GitLab Container Registry
- Kubernetes
- Rancher
- Ingress

## Project Objective

The objective of this project was to gain hands-on experience with modern DevOps practices by containerizing a web application, automating container image builds through CI/CD, publishing images to a container registry, and deploying workloads to Kubernetes.

## Deployment Workflow

1. Forked the starter repository from FAU GitLab.
2. Verified the Nyan Cat HTML webpage.
3. Triggered the GitLab CI/CD pipeline.
4. Built a container image using Kaniko.
5. Published the image to the GitLab Container Registry.
6. Created a Kubernetes Deployment and Service using Rancher.
7. Configured an Ingress resource for external access.
8. Verified successful deployment through a public URL.

## Repository Structure

    activity2/
    ├── Dockerfile
    ├── .gitlab-ci.yml
    ├── README.md
    └── www/
        └── index.html

## Live Demo

🔗 https://cis-legharevba2024.student.hpc.fau.edu

## Features

- Containerized NGINX web server
- Embedded Nyan Cat YouTube video
- Automated image builds using GitLab CI/CD
- Container image storage in GitLab Container Registry
- Kubernetes workload deployment through Rancher
- Public access through Kubernetes Ingress

## Skills Demonstrated

- Docker containerization
- Continuous Integration and Continuous Deployment (CI/CD)
- Kubernetes deployments
- Service and Ingress management
- Container registry usage
- Rancher administration
- Cloud-native application deployment

## Screenshots

Create a `screenshots/` directory and include:

- GitLab Pipeline Success
- Container Registry Image
- Rancher Deployment
- Rancher Ingress
- Running Nyan Cat Website

## Author

**Lawrence Egharevba**

## License

This project was created for educational purposes as part of CIS 5645 coursework at Florida Atlantic University.
