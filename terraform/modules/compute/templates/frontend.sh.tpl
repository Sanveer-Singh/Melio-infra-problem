#!/bin/bash
set -euxo pipefail

dnf install -y java-17-amazon-corretto-headless nginx

mkdir -p /opt/app/static

for i in 1 2 3; do
  aws s3 cp "s3://${artifact_bucket}/front-end.jar" /opt/app/front-end.jar && break || sleep 10
done
[ -f /opt/app/front-end.jar ] || { echo "FATAL: Failed to download front-end.jar after 3 attempts" >&2; exit 1; }

for i in 1 2 3; do
  aws s3 cp "s3://${artifact_bucket}/static.tgz" /opt/app/static.tgz && break || sleep 10
done
[ -f /opt/app/static.tgz ] || { echo "FATAL: Failed to download static.tgz after 3 attempts" >&2; exit 1; }

tar -xzf /opt/app/static.tgz -C /opt/app/static/

NEWSFEED_TOKEN=$(aws ssm get-parameter \
  --name "${ssm_parameter_name}" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region "${region}")

cat > /opt/app/frontend.env << ENV_EOF
APP_PORT=${frontend_port}
STATIC_URL=
QUOTE_SERVICE_URL=http://${quotes_private_ip}:${quotes_port}
NEWSFEED_SERVICE_URL=http://${newsfeed_private_ip}:${newsfeed_port}
NEWSFEED_SERVICE_TOKEN=$NEWSFEED_TOKEN
ENV_EOF

cat > /etc/systemd/system/frontend.service << 'UNIT_EOF'
[Unit]
Description=Frontend Service
After=network.target

[Service]
Type=simple
EnvironmentFile=/opt/app/frontend.env
ExecStart=/usr/bin/java -Xmx512m -XX:+UseSerialGC -jar /opt/app/front-end.jar
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT_EOF

cat > /etc/nginx/conf.d/frontend.conf << 'NGINX_EOF'
${nginx_conf}
NGINX_EOF

rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

systemctl daemon-reload
systemctl enable --now frontend
systemctl enable --now nginx

echo "User data complete for frontend" | systemd-cat -t user-data
