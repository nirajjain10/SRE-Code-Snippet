#!/bin/bash
#####
# echo "starting the build"
sudo yum -y install openssl
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
rm -f get_helm.sh
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform
#####
cd tf

terraform init
terraform plan

terraform apply --auto-approve
#####
unset CLUSTER_NAME
unset AMP_WORKSPACE_ALIAS
unset WORKSPACE_ID
unset AMP_ENDPOINT_RW

export CLUSTER_NAME="demo"
export AMP_WORKSPACE_ALIAS="demo"
export WORKSPACE_ID=$(aws amp list-workspaces --alias "${AMP_WORKSPACE_ALIAS}" --region="us-east-1" --query 'workspaces[0].[workspaceId]' --output text)
export AMP_ENDPOINT_RW=https://aps-workspaces.us-east-1.amazonaws.com/workspaces/$WORKSPACE_ID/api/v1/remote_write

echo $CLUSTER_NAME
echo $AMP_WORKSPACE_ALIAS
echo $WORKSPACE_ID
echo $AMP_ENDPOINT_RW

aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
#####
cd ../
kubectl apply -f eks-console-full-access.yaml
eksctl get iamidentitymapping --cluster demo --region=us-east-1
eksctl create iamidentitymapping --cluster demo --region=us-east-1 --arn arn:aws:iam::616766102138:user/eks-mgr --group eks-console-dashboard-full-access-group --no-duplicate-arns
eksctl create iamidentitymapping --cluster demo --region=us-east-1 --arn arn:aws:iam::616766102138:user/* --group eks-console-dashboard-full-access-group --no-duplicate-arns
kubectl create -f prometheus-operator-crd
kubectl apply -f prometheus-operator
sed -i "s?{{amp_url}}?$AMP_ENDPOINT_RW?g" ./prometheus-agent/4-prometheus.yaml
kubectl apply -f prometheus-agent
kubectl apply -f node-exporter
kubectl apply -f cadvisor
kubectl apply -f kube-state-metrics
kubectl apply -R -f grafana

