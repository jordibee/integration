#!/usr/bin/env bash


# Display help if asked.
if [[ $1 == "--help" ]]; then
  echo "This script is used to provision the Mender server. Usage:"
  echo "./mender_setup.sh MENDER_HOST MENDER_ARTIFACTS_HOST MINIO_SECRET_KEY"
  echo ""
  echo "Where:"
  echo "  - MENDER_HOST: DNS hostname used to access this server."
  echo "  - MENDER_ARTIFACTS_HOST: DNS hostname used to access this server when fetching artifacts."
  echo "  - MINIO_SECRET_KEY: Secret key used to sign URLs to fetch artifacts."
  exit 0
fi

# Some sanity checks.
if [[ $# -ne 3 ]]; then
  echo "ERROR: This command expects three arguments!"
  echo "Do ./mender_setup.sh --help to see the usage."
  exit 1
fi

# If some step fails, make the whole script fail.
set -e

# Install docker, docker-compose and other dependencies.
echo "[*] Installing docker, docker-compose and other dependencies..."
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    git
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update && sudo apt-get install -y docker-ce
sudo groupadd docker
sudo usermod -a -G docker $USER
sudo systemctl enable docker
sudo curl -L https://github.com/docker/compose/releases/download/1.24.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo usermod -a -G docker $USER

# Format and mount drive we will be using to store artifacts.
echo "[*] Formatting and mounting artifacts drive..."
sudo systemctl stop docker
sudo mkfs.ext4 /dev/disk/by-id/google-mender-data
echo '/dev/disk/by-id/google-mender-data /var/lib/docker/volumes ext4 defaults 0 2' | sudo tee --append /etc/fstab
sudo mount /var/lib/docker/volumes
sudo systemctl start docker

# Create all docker volumes.
echo "[*] Creating docker volumes..."
sudo docker volume create --name=mender-artifacts
sudo docker volume create --name=mender-db
sudo docker volume create --name=mender-elasticsearch-db
sudo docker volume create --name=mender-redis-db
sudo docker volume create --name=mender-api-gateway-actual-certs
sudo docker volume inspect --format '{{.Mountpoint}}' mender-artifacts

# Configure server.
echo "[*] Configuring server..."
pushd ./production &> /dev/null
sed -i \
  -e "s|{{MENDER_HOST}}|${1}|g" \
  -e "s|{{MENDER_ARTIFACTS_HOST}}|${2}|g" \
  -e "s|{{MINIO_SECRET_KEY}}|${3}|g" \
  ./prod.yml

# Create start up certificates.
# Note that these certificates are not really used in production but are simply
# necessary to allow nginx to start up before Let's Encrypt can create the real certificates.
CERT_API_CN=${1} CERT_STORAGE_CN=${2} ../keygen

# Start the server.
echo "[*] Starting server..."
./run up -d
popd &> /dev/null
