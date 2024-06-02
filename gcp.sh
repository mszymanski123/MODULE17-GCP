#!/bin/bash

VPC_NAME="my-vpc"
SUBNET_NAME="internship2024wro-subnet"
REGION="us-east1"
SUBNET_RANGE="10.0.0.0/24"
VM_NAME="internship2024wro-vm"
ZONE="us-central1-a"
MACHINE_TYPE="n1-standard-1"
IMAGE_FAMILY="debian-10"
IMAGE_PROJECT="debian-cloud"
ALLOW_INTERNAL="allow-internal"
ALLOW_SSH="allow-ssh"
IMAGE_NAME="spring-petclinic"
GCR_HOSTNAME="gcr.io"
PROJECT_ID=$(gcloud config get-value project)
IMAGE_TAG="$GCR_HOSTNAME/$PROJECT_ID/$IMAGE_NAME:latest"

gcloud compute networks create $VPC_NAME --subnet-mode=custom
echo "VPC $VPC_NAME created."

gcloud compute networks subnets create $SUBNET_NAME \
  --network=$VPC_NAME \
  --range=$SUBNET_RANGE \
  --region=$REGION
echo "Subnet $SUBNET_NAME created in $VPC_NAME."

gcloud services enable containerregistry.googleapis.com
echo "Container Registry API enabled."

gcloud compute instances create $VM_NAME \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --subnet=$SUBNET_NAME \
  --image-family=$IMAGE_FAMILY \
  --image-project=$IMAGE_PROJECT
echo "VM $VM_NAME created."

gcloud compute addresses create ${VM_NAME}-ip --region=$REGION

gcloud compute instances network-interfaces update $VM_NAME \
  --zone=$ZONE \
  --network-interface=nic0 \
  --address=$(gcloud compute addresses describe ${VM_NAME}-ip --region=$REGION --format="get(address)")
echo "Public IP address assigned to VM $VM_NAME."

gcloud compute firewall-rules create $ALLOW_INTERNAL \
  --network=$VPC_NAME \
  --allow=all \
  --source-ranges=10.0.0.0/24

gcloud compute firewall-rules create $ALLOW_SSH \
  --network=$VPC_NAME \
  --allow=tcp:22 \
  --source-ranges=0.0.0.0/0
echo "Firewall rules created."

gcloud auth configure-docker $REGION-docker.pkg.dev

docker pull mszymanski/spring-petclinic:latest
docker tag mszymanski/spring-petclinic:latest $REGION-docker.pkg.dev/$PROJECT/internship2024wro/spring-petclinic:latest
docker push $REGION-docker.pkg.dev/$PROJECT/internship2024/spring-petclinic:latest
gcloud compute ssh $VM_NAME --zone=$ZONE --command="curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
gcloud compute ssh $VM_NAME --zone=$ZONE --command="sudo docker run -d -p 8080:8080 $IMAGE_TAG"

echo "Container running on VM $VM_NAME."
