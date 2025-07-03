#!/bin/bash

# === Headwind MDM Installer for Debian Bookworm or Ubuntu ===
# Automatically installs all dependencies and builds the project

set -e

REPO_URL="https://github.com/h-mdm/hmdm-server.git"
INSTALL_DIR="hmdm-server"
DB_NAME="hmdm"
DB_USER="hmdm"
DB_PASS="topsecret"

echo "==> Detecting OS and installing required packages..."

# Function to install Java (try 17, fallback to 11 or 8)
install_java() {
    if ! java -version &>/dev/null; then
        echo "==> Installing OpenJDK..."
        if apt-cache search openjdk-17-jdk | grep -q openjdk-17-jdk; then
            sudo apt install -y openjdk-17-jdk
        elif apt-cache search openjdk-11-jdk | grep -q openjdk-11-jdk; then
            sudo apt install -y openjdk-11-jdk
        else
            echo "OpenJDK 17 or 11 not available, trying OpenJDK 8..."
            sudo apt install -y openjdk-8-jdk
        fi
    else
        echo "Java is already installed."
    fi
}

# Function to install Tomcat
install_tomcat() {
    if dpkg -l | grep -q tomcat9; then
        echo "Tomcat9 already installed."
    elif apt-cache search tomcat10 | grep -q tomcat10; then
        echo "==> Installing Tomcat10..."
        sudo apt install -y tomcat10
    else
        echo "Tomcat9/10 not found. Installing Tomcat manually..."
        # Fallback: download and install manually
        TOMCAT_VERSION="9.0.85"
        wget https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz
        sudo tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C /opt/
        sudo ln -sfn /opt/apache-tomcat-${TOMCAT_VERSION} /opt/tomcat
        sudo chmod +x /opt/tomcat/bin/*.sh
        sudo /opt/tomcat/bin/startup.sh
        echo "Tomcat installed manually in /opt/tomcat"
    fi
}

sudo apt update
sudo apt install -y git aapt maven postgresql curl unzip wget lsb-release

install_java
install_tomcat

echo "==> Verifying Tomcat status..."
if curl -s localhost:8080 | grep -q "Apache Tomcat"; then
    echo "Tomcat is running."
else
    echo "Tomcat is NOT responding on port 8080. Please check manually."
fi

echo "==> Cloning Headwind MDM repository..."
if [ ! -d "$INSTALL_DIR" ]; then
    git clone "$REPO_URL"
fi
cd "$INSTALL_DIR"

echo "==> Copying default build properties..."
cp -n server/build.properties.example server/build.properties

echo "==> Building project with Maven..."
mvn install

echo "==> Setting up PostgreSQL database..."
sudo -u postgres psql <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USER}') THEN
      CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASS}';
   END IF;
END
\$\$;

CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;
EOF

echo "==> Running the Headwind MDM installer..."
sudo ./hmdm_install.sh

echo "✅ DONE!"
echo "➡️  Visit http://<your-server-ip>:8080/headwind in your browser."
