#!/usr/bin/env bash

# This script installs Helm, adds Grafana and Prometheus Helm repositories,
# installs Grafana and Prometheus, and exposes their services.

set -e  # Exit immediately if a command exits with a non-zero status.

# Download and install Helm
echo "Downloading Helm installation script..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Add Grafana Helm repository
echo "Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Grafana
echo "Installing Grafana..."
helm install grafana grafana/grafana

# Expose Grafana service
echo "Exposing Grafana service..."
kubectl expose service grafana --type=NodePort --target-port=3000 --name=grafana-ext

# Add Prometheus Helm repository
echo "Adding Prometheus Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
echo "Installing Prometheus..."
helm install prometheus prometheus-community/prometheus

# Expose Prometheus service
echo "Exposing Prometheus service..."
kubectl expose service prometheus-server --type=NodePort --target-port=9090 --name=prometheus-server-ext

# Retrieve Grafana admin password
echo "Retrieving Grafana admin password..."
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo

# List all pods
echo "Listing all pods..."
kubectl get pods -o wide

echo "Script execution completed."
