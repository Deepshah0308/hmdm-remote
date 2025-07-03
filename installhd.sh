#!/bin/bash

# === Headwind MDM Automated Installer Script ===
# Works for Ubuntu 22.04 LTS (Tomcat9)
# Git repo: https://github.com/h-mdm/hmdm-server.git

set -e

REPO_URL="https://github.com/h-mdm/hmdm-server.git"
INSTALL_DIR="hmdm-server"

echo "==> Updating system and installing required packages..."
sudo apt update
sudo apt install -y git aapt tomcat9 maven postgresql openjdk-11-jdk curl

echo "==> Ensuring Tomcat is running..."
if ! curl -s localhost:8080 | grep -q "Apache Tomcat"; then
    echo "Tomcat not responding — starting service..."
    sudo systemctl start tomcat9
    sudo systemctl enable tomcat9
    sleep 5
    if ! curl -s localhost:8080 | grep -q "Apache Tomcat"; then
        echo "ERROR: Tomcat failed to start. Check installation manually."
        exit 1
    fi
fi
echo "Tomcat is running."

echo "==> Cloning the Headwind MDM repository..."
if [ -d "$INSTALL_DIR" ]; then
    echo "Directory $INSTALL_DIR already exists. Skipping clone."
else
    git clone "$REPO_URL"
fi

cd "$INSTALL_DIR"
echo "Now in $(pwd)"

echo "==> Preparing build.properties..."
cp -n server/build.properties.example server/build.properties

echo "==> Building Headwind MDM using Maven..."
mvn install

echo "==> Setting up PostgreSQL user and database..."
sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (
      SELECT
      FROM   pg_catalog.pg_user
      WHERE  usename = 'hmdm') THEN

      CREATE USER hmdm WITH PASSWORD 'topsecret';
   END IF;
END
\$do\$;

CREATE DATABASE hmdm OWNER hmdm TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C';
EOF

echo "==> Running the Headwind installer script..."
sudo ./hmdm_install.sh

echo "✅ Installation complete!"
echo "➡️  Open: http://<your-server-ip>:8080/headwind in your browser"
