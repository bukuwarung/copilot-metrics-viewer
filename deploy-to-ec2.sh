#!/bin/bash
set -e

# Configuration variables
EC2_USER="ubuntu"
EC2_IP="10.0.3.44"
SSH_KEY_PATH="$HOME/Downloads/ssh/amsal-dev.pem"
IMAGE_NAME="copilot-metrics-viewer"
CONTAINER_NAME="copilot-metrics-viewer"
ENV_FILE_PATH="./.env"
HOST_PORT=8080
CONTAINER_PORT=80

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "Error: SSH key not found at $SSH_KEY_PATH"
  echo "Please update the SSH_KEY_PATH variable in this script."
  exit 1
fi

# Build the Docker image
echo "Building Docker image: $IMAGE_NAME"
docker build -t $IMAGE_NAME .

# Save the Docker image to a tar file
echo "Saving Docker image to $IMAGE_NAME.tar"
docker save -o $IMAGE_NAME.tar $IMAGE_NAME

# Copy the tar file to EC2
echo "Copying $IMAGE_NAME.tar to EC2 instance"
scp -i "$SSH_KEY_PATH" $IMAGE_NAME.tar $EC2_USER@$EC2_IP:~/

# Copy the environment file to EC2 (if it exists locally)
if [ -f "$ENV_FILE_PATH" ]; then
  echo "Copying $ENV_FILE_PATH to EC2 instance"
  scp -i "$SSH_KEY_PATH" "$ENV_FILE_PATH" $EC2_USER@$EC2_IP:~/
else
  echo "Warning: Environment file not found at $ENV_FILE_PATH"
  echo "Make sure the .env file exists on the EC2 server."
fi

# SSH into EC2 and run commands
echo "Connecting to EC2 instance to deploy the application"
ssh -i "$SSH_KEY_PATH" $EC2_USER@$EC2_IP << EOF
  # Load the Docker image
  echo "Loading Docker image from $IMAGE_NAME.tar"
  sudo docker load < $IMAGE_NAME.tar
  
  # Stop and remove the existing container if it exists
  if sudo docker ps -a | grep -q $CONTAINER_NAME; then
    echo "Stopping and removing existing container: $CONTAINER_NAME"
    sudo docker stop $CONTAINER_NAME || true
    sudo docker rm $CONTAINER_NAME || true
  fi
  
  # Run the new container
  echo "Starting new container: $CONTAINER_NAME"
  sudo docker run --restart=always -d --name $CONTAINER_NAME -p $HOST_PORT:$CONTAINER_PORT --env-file ./.env $IMAGE_NAME
  
  # Check if container is running
  echo "Checking container status"
  sudo docker ps | grep $CONTAINER_NAME
  
  # Clean up the tar file to save space (optional)
  echo "Cleaning up tar file"
  rm $IMAGE_NAME.tar
EOF

# Clean up local tar file
echo "Cleaning up local tar file"
rm $IMAGE_NAME.tar

echo "Deployment completed successfully!"
echo "Application should be accessible at http://$EC2_IP:$HOST_PORT"
echo "To check health endpoint: http://$EC2_IP:$HOST_PORT/api/health"