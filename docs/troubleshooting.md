# Troubleshooting log

Errors hit while building the churn app pipeline (Oct 10-11, 2026), with cause and fix.
Full narrative and screenshots: `StackIT_Churn_App_Build_Documentation.docx`.

| # | Symptom | Cause | Fix |
|---|---------|-------|-----|
| 1 | `Cannot connect to the Docker daemon at unix:///var/run/docker.sock` | Docker installed but service not started | `sudo systemctl enable docker && sudo systemctl restart docker` (Packer `setup.sh` uses `enable --now`) |
| 2 | `python: command not found` on Amazon Linux 2023 | Only `python3` exists | `sudo dnf install python -y` (alias package), `sudo dnf install python3-pip` |
| 3 | `pip install sagemaker` needed a second attempt | The server does not need the full SDK dependency set | `pip install sagemaker --no-deps`; verify with `pip show sagemaker` |
| 4 | `Input required and not supplied: aws-region` | `AWS_REGION` repo variable missing | Add repo variables `AWS_REGION`, `AWS_ACCOUNT_ID` |
| 5 | `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Trust policy `sub` used the old claim format | Use `repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:refs/heads/main` (see below) |
| 6 | `repository '<account>.dkr.ecr...amazonaws.com/churn-repo' does not exist` | `ECR_REPO` held the full URL; workflow prepends the registry | Set `ECR_REPO` to the repo **name** only (`stackit-churn-repo`) |
| 7 | `cd k8s: No such file or directory` | Leftover EKS/GitOps `update-manifests` job | Delete the job from `ci-cd.yaml` |
| 8 | Deploy via SSH cannot connect | Security group SSH limited to My IP; GitHub runners have other IPs | Open SSH to `0.0.0.0/0` (temporary, retire with the SSH job) |
| 9 | `ecr:GetAuthorizationToken` AccessDenied on the instance | Instance role `sagemaker-policy` had no ECR permission | Attach ECR managed policies to the role |
| 10 | Packer: `ec2:DescribeImages` 403 | `github-actions-ecr-push` lacked EC2 read | Add a policy allowing `ec2:DescribeImages` |
| 11 | Terraform init: S3 `HeadObject` 403 | Role could not read the state bucket | Policy `s3-list-bucket-tfstate` (below) |
| 12 | Packer: `ec2:DescribeRegions` 403 | Packer makes many EC2 calls | Policy `packer-permissions` (EC2) - tighten later |

## Useful commands

```bash
# IDs for the OIDC trust policy subject claim
gh api repos/eayanwale/stack-churn-app-docker --jq '.id'
curl -s https://api.github.com/users/eayanwale        # "id" field = owner id

# Test ECR login from an instance
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 524558748095.dkr.ecr.us-east-1.amazonaws.com

# Check Docker and the app on a server
sudo systemctl status docker
docker ps && docker logs churn && curl -s localhost/health
sudo tail -n 50 /var/log/user-data.log        # boot script output on Terraform-built instances
```

## Trust policy that worked (github-actions-ecr-push)

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "arn:aws:iam::524558748095:oidc-provider/token.actions.githubusercontent.com" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": { "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:eayanwale@235366535/stack-churn-app-docker@1413523040:ref:refs/heads/main"
    } }
  }]
}
```

## S3 state bucket policy (s3-list-bucket-tfstate)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "ListStateBucket", "Effect": "Allow", "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::enoch-tf-state-bucket" },
    { "Sid": "ReadWriteStateObjects", "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::enoch-tf-state-bucket/*" }
  ]
}
```

## Running Terraform locally

`provider.tf` and `versions.tf` have `profile = "stackprog-dev"` commented out because GitHub runners
use the OIDC role. Locally, export `AWS_PROFILE=stackprog-dev` before `terraform init/plan`.
