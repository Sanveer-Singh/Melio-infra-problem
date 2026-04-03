#!/bin/bash
set -euxo pipefail

dnf install -y java-17-amazon-corretto-headless

mkdir -p /opt/app

for i in 1 2 3; do
  aws s3 cp "s3://${artifact_bucket}/newsfeed.jar" /opt/app/newsfeed.jar && break || sleep 10
done
[ -f /opt/app/newsfeed.jar ] || { echo "FATAL: Failed to download newsfeed.jar after 3 attempts" >&2; exit 1; }

cat > /opt/app/newsfeed.env << 'ENV_EOF'
APP_PORT=${newsfeed_port}
ENV_EOF

cat > /etc/systemd/system/newsfeed.service << 'UNIT_EOF'
[Unit]
Description=Newsfeed Service
After=network.target

[Service]
Type=simple
EnvironmentFile=/opt/app/newsfeed.env
ExecStart=/usr/bin/java -Xmx512m -XX:+UseSerialGC -jar /opt/app/newsfeed.jar
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT_EOF

systemctl daemon-reload
systemctl enable --now newsfeed

echo "User data complete for newsfeed" | systemd-cat -t user-data
