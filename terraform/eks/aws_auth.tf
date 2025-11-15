/*
  aws-auth management removed.

  Reason: The kubernetes provider requires network access to the cluster at plan/apply time
  to read the existing aws-auth configmap. For private EKS clusters (or when Terraform
  is run from an environment without cluster network access) this causes errors like:

    Error: Get "http://localhost/api/v1/namespaces/kube-system/configmaps/aws-auth": dial tcp [::1]:80: connectex: No connection could be made because the target machine actively refused it.

  Recommended alternative workflows:
   - Run the following script from a machine that can reach the cluster (for private clusters
     that's typically the bastion). See `scripts/patch_aws_auth.ps1` for a helper.
   - Or run `terraform apply` from a CI runner or host with network access to the EKS cluster.

  The repository provides a script `scripts/patch_aws_auth.ps1` which will SSH to the bastion
  and patch the aws-auth configmap to add the bastion role mapping.
*/

resource "null_resource" "aws_auth_placeholder" {
  # placeholder so the file exists but it doesn't require the kubernetes provider
  triggers = {
    timestamp = timestamp()
  }
}
