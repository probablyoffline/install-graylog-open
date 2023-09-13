#!/bin/bash
### Graylog Ubuntu Install 22.04 Jammy. AIO instance.

## Install MongoDB
# Install prereq
echo -e "\n[+] Installing gnupg \n"
sudo apt install -y gnupg curl
 

# Add public key
echo -e "\n[+] Adding MongoDB public key \n"
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor 

# Add mongodb repo
echo -e "\n[+] Adding mongodb repo \n"
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list


# Reload local package database
sudo apt update -y
 

# Install latest MongoDB version
echo -e "\n[+] Installing MongoDB \n"
sudo apt install -y mongodb-org
 

# Optional: Pin package version
# echo "mongodb-org hold" | sudo dpkg --set-selections
# echo "mongodb-org-database hold" | sudo dpkg --set-selections
# echo "mongodb-org-server hold" | sudo dpkg --set-selections
# echo "mongodb-mongosh hold" | sudo dpkg --set-selections
# echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
# echo "mongodb-org-tools hold" | sudo dpkg --set-selections

# Start MongoDB
echo -e "\n[+] Starting MongoDB service \n"
sudo systemctl start mongod
sudo systemctl enable mongod
 
## Install OpenSearch
echo -e "\n[+] Increase max map count\n"
# Increase max_map_count
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sudo sysctl -p

# Disable transparent hugepages

echo -e "\n[+] Disabling transparent hugepages\n"
cat > /etc/systemd/system/disable-transparent-huge-pages.service <<EOF
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'
[Install]
WantedBy=basic.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable disable-transparent-huge-pages.service
sudo systemctl start disable-transparent-huge-pages.service

# Add OpenSearch user

echo -e "\n[+] Adding OpenSearch user\n"
sudo adduser --system --disabled-password --disabled-login --home /var/empty --no-create-home --quiet --force-badname --group opensearch

# Download Opensearch 2.9.0
echo -e "\n[+] Downloading OpenSearch packages \n"
wget https://artifacts.opensearch.org/releases/bundle/opensearch/2.9.0/opensearch-2.9.0-linux-x64.tar.gz

# Create Directories
echo -e "\n[+] Creating directories \n"
sudo mkdir -p /graylog/opensearch/data
sudo mkdir /var/log/opensearch

# Extract Contents from tar
echo -e "\n[+] Extracting contents \n"
sudo tar -zxf opensearch-2.9.0-linux-x64.tar.gz
sudo mv opensearch-2.9.0/* /graylog/opensearch/

# Set Permissions
echo -e "\n[+] Setting permissions \n"
sudo chown -R opensearch:opensearch /graylog/opensearch/
sudo chown -R opensearch:opensearch /var/log/opensearch
sudo chmod -R 2750 /graylog/opensearch/
sudo chmod -R 2750 /var/log/opensearch

# Create empty log file
echo -e "\n[+] Creating empty log file \n"
sudo -u opensearch touch /var/log/opensearch/graylog.log

# Create System Service
echo -e "\n[+] Creating system services \n"
cat > /etc/systemd/system/opensearch.service <<EOF
[Unit]
Description=Opensearch
Documentation=https://opensearch.org/docs/latest
Requires=network.target remote-fs.target
After=network.target remote-fs.target
ConditionPathExists=/graylog/opensearch
ConditionPathExists=/graylog/opensearch/data
[Service]
Environment=OPENSEARCH_HOME=/graylog/opensearch
Environment=OPENSEARCH_PATH_CONF=/graylog/opensearch/config
ReadWritePaths=/var/log/opensearch
User=opensearch
Group=opensearch
WorkingDirectory=/graylog/opensearch
ExecStart=/graylog/opensearch/bin/opensearch
# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65535
# Specifies the maximum number of processes
LimitNPROC=4096
# Specifies the maximum size of virtual memory
LimitAS=infinity
# Specifies the maximum file size
LimitFSIZE=infinity
# Disable timeout logic and wait until process is stopped
TimeoutStopSec=0
# SIGTERM signal is used to stop the Java process
KillSignal=SIGTERM
# Send the signal only to the JVM rather than its control group
KillMode=process
# Java process is never killed
SendSIGKILL=no
# When a JVM receives a SIGTERM signal it exits with code 143
SuccessExitStatus=143
# Allow a slow startup before the systemd notifier module kicks in to extend the timeout
TimeoutStartSec=180
[Install]
WantedBy=multi-user.target
EOF

# Configure Graylog of OpenSearch
echo -e "\n[+] Configure OpenSearch for Graylog \n"
cat > /graylog/opensearch/config/opensearch.yml <<EOF
cluster.name: graylog
path.data: /graylog/opensearch/data
path.logs: /var/log/opensearch
network.host: 0.0.0.0
discovery.type: single-node
action.auto_create_index: false
plugins.security.disabled: true
EOF

# Get the total amount of memory in kilobytes
total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')

# Convert kilobytes to gigabytes
total_mem_gb=$(echo "scale=2; $total_mem / 1024 / 1024" | bc)

# Divide by half
half_mem_gb=$(echo "scale=2; $total_mem_gb / 2" | bc)

# Round to the nearest whole number
rounded_mem_gb=$(echo "($half_mem_gb+0.5)/1" | bc)

# Update jvm.options file with new memory value
echo -e "\n[+] Updating jvm options \n"
sed -i "s/-Xms[0-9]*[m|g]/-Xms${rounded_mem_gb}g/" /graylog/opensearch/config/jvm.options
sed -i "s/-Xmx[0-9]*[m|g]/-Xmx${rounded_mem_gb}g/" /graylog/opensearch/config/jvm.options
sed -i "s/GRAYLOG_SERVER_JAVA_OPTS=\"-Xms1g -Xmx1g/GRAYLOG_SERVER_JAVA_OPTS=\"-Xms${rounded_mem_gb}g -Xmx${rounded_mem_gb}g/" /etc/default/graylog-server

# Configure the kernel parameters at runtime
echo -e "\n[+] Configuring kernel parameters \n"
sudo sysctl -w vm.max_map_count=262144
sudo echo 'vm.max_map_count=262144' >> /etc/sysctl.conf

# Enable OpenSearch service
echo -e "\n[+] Enabling OpenSearch services \n"
sudo systemctl daemon-reload
sudo systemctl enable opensearch.service
sudo systemctl start opensearch.service

## Install Graylog
# Add repo
echo -e "\n[+] Adding Graylog repo \n"
sudo apt install -y apt-transport-https
wget https://packages.graylog2.org/repo/packages/graylog-5.1-repository_latest.deb
sudo dpkg -i graylog-5.1-repository_latest.deb
sudo apt -y update
 
# Check versions
# sudo apt-cache policy graylog-server

# Install server
echo -e "\n[+] Installing Graylog server 5.1.5 \n"
sudo apt install graylog-server=5.1.5

## Update graylog config
# Generate secrets
echo -e "\n[+] Installing pwgen \n"
sudo apt install -y pwgen
 
# Generate the secret
echo -e "\n[+] Generating secret \n"
secret=$(pwgen -N 1 -s 96)
 
# Generate graylog root password
read -s -p "Enter Graylog admin Password: " password
echo -e "\n[+] Generating Graylog root password \n"
echo -n $password | sha256sum | cut -d" " -f1 > password_sha2.txt
 
# Read password from file
echo -e "\n[+]  Setting Graylog root password \n"
password_sha2=$(cat password_sha2.txt)
 
# Get the IP address of the non-loopback interface
ip_address=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d '/' -f 1)
graylog_address="http_bind_address = $ip_address:9000"
 
# Update graylog config
echo -e "\n[+] Updating Graylog config \n"
sed -i "s/^password_secret =.*/password_secret = $secret/" /etc/graylog/server/server.conf
sed -i "s/^root_password_sha2 =.*/root_password_sha2 = $password_sha2/" /etc/graylog/server/server.conf
sed -i "s/^#http_bind_address = 127.0.0.1:9000/$graylog_address/" /etc/graylog/server/server.conf
 
# Clean up temporary files
echo -e "\n[+] Cleaning up temp files \n"
rm password_sha2.txt
 
# Start graylog
echo -e "\n[+] Starting Graylog services \n"
sudo systemctl start graylog-server
sudo systemctl enable graylog-server
 
echo -e "\n[+] Clearing user history \n"
history -c

echo -e "\n[+] Install Complete \n"
