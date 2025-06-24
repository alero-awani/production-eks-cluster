#!/bin/bash
echo "Cleaning up Kubernetes LoadBalancer resources..."
kubectl delete ingress --all --all-namespaces
kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer

echo "Waiting for AWS to delete associated ALBs..."
sleep 90  # Optional: adjust as needed

echo "Now running terraform destroy"

# Example to delete security groups with specific tags
aws ec2 describe-security-groups --filters Name=tag:app,Values=my-app \
  --query "SecurityGroups[].GroupId" --output text | \
  xargs -n1 aws ec2 delete-security-group --group-id

terraform destroy -auto-approve