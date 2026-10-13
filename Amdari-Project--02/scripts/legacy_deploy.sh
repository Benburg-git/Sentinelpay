
#!/usr/bin/env bash
# legacy_deploy.sh
#
# DEPRECATED — historical deployment reference only.
# SentinelPay deployments are now managed through GitHub Actions
# using AWS OIDC authentication and temporary IAM credentials.
#
# Do not use this script for production deployments.

set -euo pipefail

echo "SentinelPay legacy deployment script"
echo "Status: DEPRECATED"
echo "Use the approved GitHub Actions CI/CD workflow instead."

# Historical deployment configuration:
# AWS_REGION was previously configured for af-south-1.
#
# Production database credentials must be retrieved securely
# from AWS Secrets Manager.
#
# Notification webhooks and partner API credentials must be
# injected securely at runtime.
#
# Do not store passwords, access keys, or webhook URLs in Git.

exit 0
