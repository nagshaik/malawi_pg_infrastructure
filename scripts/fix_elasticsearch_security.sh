#!/bin/bash
# Script to disable Elasticsearch X-Pack security and restart services

echo "=== Fixing Elasticsearch Security Configuration ==="

# Stop Elasticsearch
sudo systemctl stop elasticsearch

# Backup current config
sudo cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.backup

# Update Elasticsearch config to disable security
sudo sed -i '/xpack.security.enabled/d' /etc/elasticsearch/elasticsearch.yml
sudo sed -i '/xpack.security.enrollment/d' /etc/elasticsearch/elasticsearch.yml
sudo sed -i '/xpack.security.http.ssl/d' /etc/elasticsearch/elasticsearch.yml
sudo sed -i '/xpack.security.transport.ssl/d' /etc/elasticsearch/elasticsearch.yml

# Add explicit security disabled settings
echo "" | sudo tee -a /etc/elasticsearch/elasticsearch.yml
echo "# Security disabled for internal VPC use" | sudo tee -a /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.enabled: false" | sudo tee -a /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.enrollment.enabled: false" | sudo tee -a /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.http.ssl.enabled: false" | sudo tee -a /etc/elasticsearch/elasticsearch.yml
echo "xpack.security.transport.ssl.enabled: false" | sudo tee -a /etc/elasticsearch/elasticsearch.yml

# Start Elasticsearch
sudo systemctl start elasticsearch

# Wait for ES to start
echo "Waiting for Elasticsearch to start..."
sleep 10

# Check status
sudo systemctl status elasticsearch --no-pager

# Test connection
echo ""
echo "Testing Elasticsearch connection..."
sleep 5
curl -X GET "http://localhost:9200" || echo "Still starting up..."

echo ""
echo "=== Configuration complete ==="
echo "Run this on both Elasticsearch nodes: 10.16.128.10 and 10.16.144.10"
