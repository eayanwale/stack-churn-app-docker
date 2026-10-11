#!/bin/bash
set -euo pipefail

sudo dnf update -y
sudo dnf install -y docker git

sudo systemctl enable --now docker

sudo usermod -aG docker ec2-user
sudo docker --version