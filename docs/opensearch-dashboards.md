# OpenSearch Dashboards: Access and Verification

This guide shows how to view Kubernetes logs shipped by Fluent Bit in OpenSearch Dashboards for the VPC-only domain.

## Prerequisites
- Bastion host reachable via SSH (public IP)
- Your SSH private key file path
- OpenSearch master user credentials (username/password)
- OpenSSH client available on your machine (Windows 10+ includes `ssh`)

## 1) Create an SSH tunnel
Forward a local port (8443) to the OpenSearch domain’s TLS (443) through the bastion.

Windows PowerShell (replace placeholders):

```powershell
ssh -i "C:\\Path\\To\\your-key.pem" -L 8443:vpc-malawi-pg-elk-cluster-s5fqgvti5w3popzer6dv5ziz5m.eu-central-1.es.amazonaws.com:443 ubuntu@<bastion_public_ip>
```

Keep this session open while you use Dashboards.

Tip: You can also run the helper script:
```powershell
scripts\tunnel_opensearch.ps1 -BastionHost <bastion_public_ip> -KeyPath "C:\\Path\\To\\your-key.pem"
```

## 2) Open Dashboards
Browse to:

- https://localhost:8443/_dashboards

You may see a certificate warning (hostname mismatch) due to tunneling; proceed to the site.

## 3) Log in
- Username: your OpenSearch master/admin user
- Password: your OpenSearch master/admin password

## 4) Create an index pattern (first-time)
- Stack Management → Index Patterns → Create index pattern
- Index pattern: `new_cluster_logs-*`
- Time field: `@timestamp`
- Save

## 5) View logs
- Go to Discover → choose `new_cluster_logs-*`
- Set time range (e.g., Last 15 minutes)
- Useful filters:
  - `kubernetes.namespace_name: "ns-pgvnext-core-api"`
  - `kubernetes.labels.app: "prod-app"`

## 6) Quick CLI checks (from bastion)
List indices:
```bash
curl -u <user>:'<pass>' -k "https://vpc-malawi-pg-elk-cluster-s5fqgvti5w3popzer6dv5ziz5m.eu-central-1.es.amazonaws.com/_cat/indices/new_cluster_logs-*?v"
```
Count today’s docs:
```bash
curl -u <user>:'<pass>' -k "https://vpc-malawi-pg-elk-cluster-s5fqgvti5w3popzer6dv5ziz5m.eu-central-1.es.amazonaws.com/new_cluster_logs-$(date +%Y.%m.%d)/_count"
```

## Troubleshooting
- 401/403: Use the master/admin user, or ensure your role has index read permissions.
- Empty Discover: Confirm index pattern exists and time range is correct; verify ingestion with curl.
- Tunnel won’t connect: Ensure bastion can reach the domain on 443 and its security group allows outbound; your local port 8443 must be free.
- TLS warnings: Expected when tunneling; use `-k` with curl and proceed in browser.

## Security notes
- Avoid committing credentials or AWS keys to version control.
- Store app secrets in Kubernetes Secrets or AWS Systems Manager Parameter Store.
- For OpenSearch credentials in Fluent Bit, reference a Secret instead of inline values.
