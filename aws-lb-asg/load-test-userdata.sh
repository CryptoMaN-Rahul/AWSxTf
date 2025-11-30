#!/bin/bash
set -e

# Update system
apt-get update -y

# Install Apache Bench
apt-get install -y apache2-utils

# Install Siege
apt-get install -y siege

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Create CloudWatch config
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
{
  "metrics": {
    "namespace": "LoadTester",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_IDLE",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Create load test scripts
cat > /home/ubuntu/light-load.sh <<'SCRIPT'
#!/bin/bash
echo "Starting LIGHT load test..."
ab -n 1000 -c 10 http://${alb_dns}/
SCRIPT

cat > /home/ubuntu/medium-load.sh <<'SCRIPT'
#!/bin/bash
echo "Starting MEDIUM load test..."
ab -n 10000 -c 50 http://${alb_dns}/
SCRIPT

cat > /home/ubuntu/heavy-load.sh <<'SCRIPT'
#!/bin/bash
echo "Starting HEAVY load test..."
ab -n 50000 -c 100 http://${alb_dns}/
SCRIPT

cat > /home/ubuntu/continuous-load.sh <<'SCRIPT'
#!/bin/bash
echo "Starting CONTINUOUS load test for 5 minutes..."
siege -c 100 -t 5M http://${alb_dns}/
SCRIPT

cat > /home/ubuntu/extreme-load.sh <<'SCRIPT'
#!/bin/bash
echo "Starting EXTREME load test (use with caution!)..."
siege -c 200 -t 10M http://${alb_dns}/
SCRIPT

# Make scripts executable
chmod +x /home/ubuntu/*.sh
chown ubuntu:ubuntu /home/ubuntu/*.sh

# Create README
cat > /home/ubuntu/README.txt <<'README'
Load Testing Scripts Available:
================================

./light-load.sh     - Light load: 1,000 requests, 10 concurrent users
./medium-load.sh    - Medium load: 10,000 requests, 50 concurrent users
./heavy-load.sh     - Heavy load: 50,000 requests, 100 concurrent users
./continuous-load.sh - Continuous: 100 concurrent users for 5 minutes
./extreme-load.sh   - EXTREME: 200 concurrent users for 10 minutes (USE WITH CAUTION!)

Manual Commands:
================

Apache Bench (ab):
  ab -n <requests> -c <concurrent> http://${alb_dns}/

Siege:
  siege -c <concurrent> -t <time> http://${alb_dns}/
  Example: siege -c 50 -t 2M http://${alb_dns}/

Monitor in real-time:
  watch -n 1 'ab -n 100 -c 10 http://${alb_dns}/ 2>&1 | tail -20'

Target ALB: http://${alb_dns}/
README

chown ubuntu:ubuntu /home/ubuntu/README.txt

echo "Load tester setup complete!"
echo "ALB DNS: ${alb_dns}"
