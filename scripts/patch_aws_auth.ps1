<#
Powershell helper to patch aws-auth ConfigMap from the bastion host.
Usage:
  .\scripts\patch_aws_auth.ps1 -BastionIp <ip> -SshKeyPath <path-to-key.pem> -BastionRoleArn <arn>

This script SSHs to the bastion and appends the bastion role mapping into the aws-auth ConfigMap
in a safe way (it fetches the current YAML, inserts the mapping under the `mapRoles` block and applies it).

Requirements on bastion:
- kubectl installed and configured to access the cluster (our bastion user-data installs kubectl)
- awk and sed available (standard on Ubuntu)
- the SSH key must allow connecting to the bastion as the ubuntu user
#>
param(
  [Parameter(Mandatory=$true)] [string] $BastionIp,
  [Parameter(Mandatory=$true)] [string] $SshKeyPath,
  [Parameter(Mandatory=$true)] [string] $BastionRoleArn
)

$remoteCmd = @"
set -eux
TMP_ORIG=/tmp/aws-auth.yaml
TMP_NEW=/tmp/aws-auth-new.yaml
kubectl get configmap aws-auth -n kube-system -o yaml > $TMP_ORIG
# Insert the new role mapping into the mapRoles block. This awk script finds the mapRoles: | line
# and appends the new mapping before the next top-level key. It is conservative and writes a new file.
awk -v arn='${BastionRoleArn}' '
  BEGIN { added=0 }
  /^  mapRoles: *\|/ { print; inmap=1; next }
  inmap && /^  [^ ]/ { # next top-level key (2 spaces then non-space)
    # append new mapping before leaving map block
    print "    - rolearn: " arn
    print "      username: bastion"
    print "      groups:"
    print "      - system:masters"
    added=1
    inmap=0
  }
  { print }
  END { if(inmap && !added) {
      # file ended while still in mapRoles block; append mapping
      print "    - rolearn: " arn
      print "      username: bastion"
      print "      groups:"
      print "      - system:masters"
    }
  }
' $TMP_ORIG > $TMP_NEW

# apply the new configmap
kubectl apply -f $TMP_NEW -n kube-system
rm -f $TMP_ORIG $TMP_NEW
"@

Write-Host "SSHing to bastion $BastionIp and patching aws-auth..."
# Use OpenSSH (available on modern Windows). Ensure path to key is correct.
$sshCmd = "ssh -o StrictHostKeyChecking=no -i `"$SshKeyPath`" ubuntu@$BastionIp << 'REMOTE'
$remoteCmd
REMOTE"

Write-Host "Running remote commands. You may be prompted for SSH passphrase if any."
Invoke-Expression $sshCmd

Write-Host "Done. Verify in cluster: kubectl get configmap aws-auth -n kube-system -o yaml"}