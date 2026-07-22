# GCP User Registration App + MongoDB Atlas + Terraform

This project creates:

- Responsive frontend similar to the supplied reference image
- Flask REST backend
- MongoDB Atlas database connection
- Nginx reverse proxy
- Docker Compose deployment
- Custom GCP VPC and subnet
- HTTP and restricted SSH firewall rules
- Static external IP
- Ubuntu Compute Engine VM
- Automatic application upload and deployment through Terraform

## Architecture

```text
Browser
   |
Static GCP IP :80
   |
Nginx container
   |----------------------|
Frontend container     Backend Flask container
                            |
                     MongoDB Atlas cluster
```

## Important security action

The database password shared in chat should be considered exposed. Change that Atlas database-user password before deployment. Do not commit the real URI to Git.

The `@` character in MongoDB usernames/passwords must be percent-encoded as `%40`.

## 1. Prerequisites

Install locally:

- Google Cloud CLI
- Terraform
- A Google Cloud billing-enabled project
- MongoDB Atlas cluster and database user

Authenticate:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project gcp-project-03803aec-3f89-45cb-896
```

## 2. Prepare Terraform variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:

- correct project ID
- your public IP with `/32`
- newly rotated MongoDB Atlas URI

Get your public IP:

```bash
curl -4 ifconfig.me
```

Example encoded password:

```text
Raw password: Example@123
Encoded:      Example%40123
```

## 3. Initialize and deploy

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply
```

Type `yes`.

## 4. Add GCP static IP to MongoDB Atlas

After apply:

```bash
terraform output atlas_allowlist_cidr
```

In Atlas:

```text
Security → Network Access → Add IP Address
```

Add the exact `/32` output. Do not use `0.0.0.0/0` for production.

The backend may show database connection errors until Atlas allows the VM IP.

## 5. Terraform outputs

After `terraform apply`, Terraform prints frontend, backend and SSH details automatically.

Show the complete summary:

```bash
terraform output deployment_summary
```

Frontend URL:

```bash
terraform output -raw frontend_url
```

Backend API URL:

```bash
terraform output -raw backend_api_url
```

Backend health URL:

```bash
terraform output -raw backend_health_url
```

Test backend:

```bash
curl "$(terraform output -raw backend_health_url)"
curl "$(terraform output -raw backend_api_url)"
```

## 6. SSH and container commands

Connect to the VM:

```bash
$(terraform output -raw ssh_command)
```

Check all containers directly from your local system:

```bash
eval "$(terraform output -raw docker_status_command)"
```

After SSH:

```bash
cd /opt/user-registration
sudo docker compose ps
sudo docker compose logs -f backend
sudo docker compose logs -f frontend
sudo docker compose logs -f nginx
```

Expected containers:

```text
user-registration-backend
user-registration-frontend
user-registration-nginx
```

## 7. Redeploy after changing application code

Run:

```bash
cd terraform
terraform apply
```

The application checksum trigger uploads and rebuilds changed files.

## 8. Destroy infrastructure

```bash
terraform destroy
```

## Notes

- The MongoDB URI is marked sensitive, but Terraform state can still contain sensitive values. Protect the state file and never upload it to Git.
- The generated SSH private key is saved as `terraform/gcp-user-app-key` and excluded by `.gitignore`.
- For production, add HTTPS using a domain, managed certificate and load balancer, and store secrets outside Terraform state.
