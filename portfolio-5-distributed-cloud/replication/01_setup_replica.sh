#!/usr/bin/env bash
# P5 - create a streaming replica of the primary (port 55432, Unix socket in /tmp). Safe to re-run.
set -euo pipefail
PGBIN=/usr/lib/postgresql/16/bin
REPL="$HOME/exam_replica"
HBA=/etc/postgresql/16/main/pg_hba.conf

if "$PGBIN"/pg_isready -q -h /tmp -p 55432; then echo "replica already running on 55432"; exit 0; fi

# 1. let the replication connection in over the Unix socket (line goes at the TOP of pg_hba.conf)
if ! sudo grep -q '# exam-replica' "$HBA"; then
    sudo sed -i '1i # exam-replica\nlocal replication all trust' "$HBA"
    psql -X -At -d postgres -c "SELECT pg_reload_conf()" >/dev/null
fi

# 2. fresh base backup
"$PGBIN"/pg_ctl -D "$REPL" stop -m fast >/dev/null 2>&1 || true
rm -rf "$REPL"
PGPASSWORD="" "$PGBIN"/pg_basebackup -h /var/run/postgresql -U "$(whoami)" -D "$REPL" -X stream -R --checkpoint=fast

# 3. Ubuntu keeps config in /etc, so the backup has no postgresql.conf / pg_hba.conf: write them
MAXC=$(psql -X -At -d postgres -c "SHOW max_connections")
cat > "$REPL/postgresql.conf" <<CONF
port = 55432
listen_addresses = ''
unix_socket_directories = '/tmp'
hot_standby = on
max_connections = $MAXC
CONF
sudo cat "$HBA" > "$REPL/pg_hba.conf"
sudo cat /etc/postgresql/16/main/pg_ident.conf > "$REPL/pg_ident.conf"
chmod 700 "$REPL"

# 4. start it
"$PGBIN"/pg_ctl -D "$REPL" -l "$REPL/replica.log" -w start
echo "replica started"
