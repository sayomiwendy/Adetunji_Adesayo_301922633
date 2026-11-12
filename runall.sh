#!/usr/bin/env bash
# runall.sh - runs portfolios 1-5 in order, commits + pushes each, then collects my_results.txt.
#   bash runall.sh        # all five
#   bash runall.sh 3      # resume from portfolio 3
# Run it from the repo folder (/workspaces/<your-repo>).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
REPO="$(pwd)"
START="${1:-1}"
FOLDERS=(portfolio-1-database-design portfolio-2-query-optimisation portfolio-3-transactions-concurrency portfolio-4-nosql portfolio-5-distributed-cloud)

# 1. find the kit (re-unzip the fixed zip if the Codespace lost ~/kit)
KIT="$(find "$HOME/kit" -maxdepth 2 -type d -name 'portfolio-1-*' -printf '%h\n' 2>/dev/null | head -1 || true)"
if [ -z "$KIT" ]; then
  Z="$(ls "$REPO"/*FIXED*.zip "$REPO"/*fixed*.zip 2>/dev/null | head -1 || true)"
  [ -n "$Z" ] || { echo "!!! kit not found and no FIXED zip in the repo - send Joseph a screenshot"; exit 1; }
  mkdir -p "$HOME/kit"; unzip -o -q "$Z" -d "$HOME/kit"
  KIT="$(find "$HOME/kit" -maxdepth 2 -type d -name 'portfolio-1-*' -printf '%h\n' | head -1)"
fi
echo "kit: $KIT"

# 2. start the databases (a sleeping Codespace stops them) and make sure the setup was done
sudo pg_ctlcluster 16 main start 2>/dev/null || true
for i in $(seq 1 15); do psql -X -d postgres -c 'SELECT 1' >/dev/null 2>&1 && break; sleep 1; done
if ! psql -X -d postgres -c 'SELECT 1' >/dev/null 2>&1; then echo "database role missing - running setup.sh"; bash "$KIT/setup.sh" 2>&1 | tee setup_output.log; fi
if ! python3 -c 'import psycopg2' 2>/dev/null; then
  pip install psycopg2-binary 2>/dev/null || pip install --user psycopg2-binary 2>/dev/null || pip install --break-system-packages psycopg2-binary 2>/dev/null \
   || pip install --user --break-system-packages psycopg2-binary 2>/dev/null || sudo apt-get install -y python3-psycopg2
  python3 -c 'import psycopg2' || { echo "!!! psycopg2 could not be installed - send Joseph a screenshot"; exit 1; }
fi
if ! pgrep -x mongod >/dev/null; then
  sudo mkdir -p /data/db /var/log/mongodb; sudo chown -R mongodb:mongodb /data/db /var/log/mongodb 2>/dev/null || true
  sudo runuser -u mongodb -- /usr/bin/mongod --dbpath /data/db --logpath /var/log/mongodb/mongod.log --bind_ip 127.0.0.1 --port 27017 --fork >/dev/null
fi
for i in $(seq 1 20); do mongosh --quiet --eval 'db.runCommand({ping:1}).ok' >/dev/null 2>&1 && break; sleep 1; done

# 3. the five portfolios
N=0
for F in "${FOLDERS[@]}"; do
  N=$((N+1))
  [ "$N" -ge "$START" ] || continue
  echo; echo "################  P$N  ($F)  ################"
  rm -rf "$REPO/$F"; cp -r "$KIT/$F" "$REPO/$F"
  if ! ( cd "$REPO/$F" && bash "run_p$N.sh" 2>&1 | tee "p${N}_output.log" ); then
    echo "!!! P$N FAILED - send Joseph the file $F/p${N}_output.log"; exit 1
  fi
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m "P$N: $F - run complete with output logs" || true
  git -C "$REPO" push -q || echo "(push failed - check that the repo has a remote; continuing)"
done

# 4. results file
cp -f "$KIT/collect_results.sh" "$REPO/collect_results.sh" 2>/dev/null || true
bash "$REPO/collect_results.sh"
git -C "$REPO" add -A; git -C "$REPO" commit -q -m "Add my_results.txt" || true; git -C "$REPO" push -q || true
code "$REPO/my_results.txt" 2>/dev/null || echo "Open my_results.txt, press Ctrl+A, Ctrl+C and paste it to Joseph."
