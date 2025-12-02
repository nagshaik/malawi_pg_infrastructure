# Logging (Fluent Bit)

This folder contains manifests to deploy Fluent Bit as a DaemonSet in the `logging` namespace for cluster log collection.

Deployment order:
1. `fluent-bit-namespace.yaml`
2. `fluent-bit-serviceaccount.yaml`
3. `fluent-bit-clusterrole.yaml`
4. `fluent-bit-clusterrolebinding.yaml`
5. `fluent-bit-configmap.yaml`
6. `fluent-bit-daemonset.yaml`

Key configuration:
- Inputs: Tail `/var/log/containers/*.log`
- Filters: Kubernetes metadata enrichment, docker JSON parser
- Output: ElasticSearch at `10.16.128.10:9200` (TLS on, verify off) with index prefix `new_cluster_logs`
- Health: HTTP server on port `2020`

Quick commands (PowerShell):
```
&"C:\Program Files\Lens\resources\x64\kubectl.exe" -n logging get pods -l app.kubernetes.io/name=fluent-bit
&"C:\Program Files\Lens\resources\x64\kubectl.exe" -n logging logs -f fluent-bit-<pod-name>
```

Notes:
- Parser file path is `/fluent-bit/etc/parsers.conf` mounted from the ConfigMap.
- DaemonSet starts with `-c /fluent-bit/etc/fluent-bit.conf`.
