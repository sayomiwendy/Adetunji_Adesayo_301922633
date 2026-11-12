#!/usr/bin/env bash
# setup.sh - provision PostgreSQL 16 + MongoDB 8 + psycopg2 in GitHub Codespaces. Run FIRST.
#   bash setup.sh 2>&1 | tee setup_output.log
set -euo pipefail
ME="$(whoami)"
echo ">>> [1/5] apt packages"
sudo rm -f /etc/apt/sources.list.d/yarn.list            # expired key breaks apt-get update
sudo apt-get update -y || true
sudo apt-get install -y curl ca-certificates gnupg lsb-release wget python3-pip postgresql postgresql-contrib || true

echo ">>> [2/5] PostgreSQL 16"
sudo pg_ctlcluster 16 main start 2>/dev/null || true
sleep 2
sudo runuser -u postgres -- psql -c "CREATE ROLE ${ME} SUPERUSER LOGIN;" 2>/dev/null || true
sudo runuser -u postgres -- psql -c "CREATE DATABASE ${ME} OWNER ${ME};" 2>/dev/null || true
psql -d postgres -c "SELECT version();"

echo ">>> [3/5] MongoDB 8"
if ! command -v mongod >/dev/null 2>&1; then
  curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/8.0 multiverse" \
    | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null
  sudo apt-get update -y || true
  sudo apt-get install -y mongodb-org
fi
sudo mkdir -p /data/db /var/log/mongodb
sudo chown -R mongodb:mongodb /data/db /var/log/mongodb 2>/dev/null || true
pgrep -x mongod >/dev/null || sudo runuser -u mongodb -- /usr/bin/mongod --dbpath /data/db --logpath /var/log/mongodb/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork
for i in $(seq 1 20); do mongosh --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1 && break; sleep 1; done
mongosh --quiet --eval 'db.runCommand({ping:1})'

echo ">>> [4/5] Python driver psycopg2 (needed by P3)"
python3 -c 'import psycopg2' 2>/dev/null \
 || pip install psycopg2-binary 2>/dev/null || pip install --user psycopg2-binary 2>/dev/null \
 || pip install --break-system-packages psycopg2-binary 2>/dev/null || pip install --user --break-system-packages psycopg2-binary 2>/dev/null \
 || sudo apt-get install -y python3-psycopg2 || true
python3 -c 'import psycopg2; print("psycopg2 OK", psycopg2.__version__)'

echo ">>> [5/5] summary"
pg_lsclusters; mongod --version | head -1
echo "Setup complete. Next: bash runall.sh"
