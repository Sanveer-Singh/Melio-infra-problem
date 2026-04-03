#!/bin/bash
set -euxo pipefail

dnf install -y java-17-amazon-corretto-headless

mkdir -p /opt/app

for i in 1 2 3; do
  aws s3 cp "s3://${artifact_bucket}/quotes.jar" /opt/app/quotes.jar && break || sleep 10
done
[ -f /opt/app/quotes.jar ] || { echo "FATAL: Failed to download quotes.jar after 3 attempts" >&2; exit 1; }

cat > /opt/app/quotes.env << 'ENV_EOF'
APP_PORT=${quotes_port}
ENV_EOF

cat > /etc/systemd/system/quotes.service << 'UNIT_EOF'
[Unit]
Description=Quotes Service
After=network.target

[Service]
Type=simple
EnvironmentFile=/opt/app/quotes.env
ExecStart=/usr/bin/java -Xmx512m -XX:+UseSerialGC -jar /opt/app/quotes.jar
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT_EOF

systemctl daemon-reload
systemctl enable --now quotes

echo "User data complete for quotes" | systemd-cat -t user-data
