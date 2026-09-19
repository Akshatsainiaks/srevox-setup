#!/usr/bin/env bash
# ==============================================================================
# Srevox Host Machine Monitoring Agent Installation Script
# ==============================================================================

set -e

SERVER_URL=""
AGENT_TOKEN=""
INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="srevox-machine-agent"

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --server)
      SERVER_URL="$2"
      shift 2
      ;;
    --token)
      AGENT_TOKEN="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$SERVER_URL" ] || [ -z "$AGENT_TOKEN" ]; then
  echo "❌ Error: --server and --token arguments are required."
  echo "Usage: curl -fsSL <URL>/srevox-machine-agent.sh | bash -s -- --server <SERVER_URL> --token <AGENT_TOKEN>"
  exit 1
fi

echo "🚀 Installing Srevox Host Agent..."

# Write telemetry loop collector script
cat <<'EOF' > /tmp/srevox-collector.sh
#!/usr/bin/env bash

SERVER_URL="$1"
AGENT_TOKEN="$2"

if [ -z "$SERVER_URL" ] || [ -z "$AGENT_TOKEN" ]; then
  echo "Missing SERVER_URL or AGENT_TOKEN"
  exit 1
fi

get_top_processes_json() {
  local sort_flag="$1"
  local ps_out
  ps_out=$(ps -eo pid,comm,%cpu,%mem --sort="$sort_flag" --no-headers 2>/dev/null | head -5)
  if [ -z "$ps_out" ]; then
    echo "[]"
    return
  fi
  local json="["
  local count=0
  while read -r r_pid r_comm r_cpu r_mem; do
    [ -z "$r_pid" ] && continue
    local clean_comm
    clean_comm=$(echo "$r_comm" | tr -d '"\\')
    [ $count -gt 0 ] && json="${json},"
    json="${json}{\"pid\":$r_pid,\"name\":\"$clean_comm\",\"cpu_pct\":${r_cpu:-0},\"mem_pct\":${r_mem:-0}}"
    count=$((count + 1))
  done <<< "$ps_out"
  json="${json}]"
  echo "$json"
}

get_net_bytes() {
  if [ -f /proc/net/dev ]; then
    awk '
      NR > 2 {
        gsub(":", " ");
        if ($1 != "lo") {
          rx += $2;
          tx += $10;
        }
      }
      END {
        printf "%.0f %.0f", (rx ? rx : 0), (tx ? tx : 0)
      }
    ' /proc/net/dev 2>/dev/null || echo "0 0"
  else
    echo "0 0"
  fi
}

get_metrics_json() {
  local passed_rx_sec="$1"
  local passed_tx_sec="$2"

  HOSTNAME=$(hostname 2>/dev/null || echo "unknown-host")
  IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
  OS=$(uname -s 2>/dev/null || echo "Linux")
  ARCH=$(uname -m 2>/dev/null || echo "x86_64")
  CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)

  # Meminfo (safe parsing preventing negative percentages)
  MEM_TOTAL_KB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
  MEM_AVAIL_KB=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo "")
  if [ -z "$MEM_AVAIL_KB" ] || [ "$MEM_AVAIL_KB" -eq 0 ] 2>/dev/null; then
    MEM_FREE_KB=$(awk '/^MemFree:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    MEM_BUFFERS_KB=$(awk '/^Buffers:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    MEM_CACHED_KB=$(awk '/^Cached:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    MEM_AVAIL_KB=$(( ${MEM_FREE_KB:-0} + ${MEM_BUFFERS_KB:-0} + ${MEM_CACHED_KB:-0} ))
  fi
  if [ "$MEM_AVAIL_KB" -gt "$MEM_TOTAL_KB" ] 2>/dev/null; then
    MEM_AVAIL_KB="$MEM_TOTAL_KB"
  fi
  MEM_USED_KB=$(( ${MEM_TOTAL_KB:-0} - ${MEM_AVAIL_KB:-0} ))
  if [ "$MEM_USED_KB" -lt 0 ] 2>/dev/null; then
    MEM_USED_KB=0
  fi
  MEM_TOTAL_BYTES=$(( ${MEM_TOTAL_KB:-0} * 1024 ))
  MEM_USED_BYTES=$(( ${MEM_USED_KB:-0} * 1024 ))
  if [ "$MEM_TOTAL_KB" -gt 0 ] 2>/dev/null; then
    MEM_PCT=$(awk "BEGIN {printf \"%.2f\", ($MEM_USED_KB / $MEM_TOTAL_KB) * 100}")
  else
    MEM_PCT="0.00"
  fi

  # Disk info (root partition /)
  DISK_INFO=$(df -B1 / | tail -n 1)
  DISK_TOTAL_BYTES=$(echo "$DISK_INFO" | awk '{print $2}')
  DISK_USED_BYTES=$(echo "$DISK_INFO" | awk '{print $3}')
  DISK_PCT=$(echo "$DISK_INFO" | awk '{print $5}' | tr -d '%')

  # Load averages
  LOADS=$(cat /proc/loadavg 2>/dev/null || echo "0 0 0")
  LOAD_1M=$(echo "$LOADS" | awk '{print $1}')
  LOAD_5M=$(echo "$LOADS" | awk '{print $2}')
  LOAD_15M=$(echo "$LOADS" | awk '{print $3}')

  # Network baseline sample before sleep
  NET_S1=($(get_net_bytes))

  # CPU usage sample over 0.5 sec
  CPU_PREV=($(grep '^cpu ' /proc/stat 2>/dev/null || echo ""))
  sleep 0.5
  CPU_NEXT=($(grep '^cpu ' /proc/stat 2>/dev/null || echo ""))

  NET_S2=($(get_net_bytes))
  
  PREV_IDLE=$(( ${CPU_PREV[4]:-0} + ${CPU_PREV[5]:-0} ))
  NEXT_IDLE=$(( ${CPU_NEXT[4]:-0} + ${CPU_NEXT[5]:-0} ))
  
  PREV_TOTAL=0
  for i in "${CPU_PREV[@]:1}"; do PREV_TOTAL=$((PREV_TOTAL + i)); done
  NEXT_TOTAL=0
  for i in "${CPU_NEXT[@]:1}"; do NEXT_TOTAL=$((NEXT_TOTAL + i)); done
  
  TOTAL_DIFF=$((NEXT_TOTAL - PREV_TOTAL))
  IDLE_DIFF=$((NEXT_IDLE - PREV_IDLE))
  
  if [ "$TOTAL_DIFF" -gt 0 ] 2>/dev/null; then
    CPU_PCT=$(awk "BEGIN {printf \"%.2f\", (($TOTAL_DIFF - $IDLE_DIFF) / $TOTAL_DIFF) * 100}")
  else
    CPU_PCT="0.00"
  fi

  # Calculate network rate in bytes per second
  if [ -n "$passed_rx_sec" ] && [ -n "$passed_tx_sec" ]; then
    NET_RX_SEC="$passed_rx_sec"
    NET_TX_SEC="$passed_tx_sec"
  else
    DIFF_RX=$(( ${NET_S2[0]:-0} - ${NET_S1[0]:-0} ))
    DIFF_TX=$(( ${NET_S2[1]:-0} - ${NET_S1[1]:-0} ))
    [ "$DIFF_RX" -lt 0 ] && DIFF_RX=0
    [ "$DIFF_TX" -lt 0 ] && DIFF_TX=0
    NET_RX_SEC=$((DIFF_RX * 2))
    NET_TX_SEC=$((DIFF_TX * 2))
  fi

  COLLECTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
  TOP_CPU_JSON=$(get_top_processes_json "-%cpu")
  TOP_MEM_JSON=$(get_top_processes_json "-%mem")

  cat <<JSON
{
  "hostname": "$HOSTNAME",
  "ip_address": "$IP_ADDR",
  "os": "$OS",
  "arch": "$ARCH",
  "cpu_cores": $CPU_CORES,
  "cpu_usage_pct": $CPU_PCT,
  "total_memory_bytes": $MEM_TOTAL_BYTES,
  "memory_used_bytes": $MEM_USED_BYTES,
  "memory_usage_pct": $MEM_PCT,
  "total_disk_bytes": $DISK_TOTAL_BYTES,
  "disk_used_bytes": $DISK_USED_BYTES,
  "disk_usage_pct": $DISK_PCT,
  "network_rx_bytes_sec": ${NET_RX_SEC:-0},
  "network_tx_bytes_sec": ${NET_TX_SEC:-0},
  "load_avg_1m": $LOAD_1M,
  "load_avg_5m": $LOAD_5M,
  "load_avg_15m": $LOAD_15M,
  "collected_at": "$COLLECTED_AT",
  "top_processes": $TOP_CPU_JSON,
  "top_cpu_processes": $TOP_CPU_JSON,
  "top_mem_processes": $TOP_MEM_JSON
}
JSON
}

BUFFER_DIR="/var/lib/srevox"
if ! mkdir -p "$BUFFER_DIR" 2>/dev/null; then
  BUFFER_DIR="/tmp/srevox"
  mkdir -p "$BUFFER_DIR" 2>/dev/null || true
fi
BUFFER_FILE="${BUFFER_DIR}/pending.jsonl"

send_payload() {
  local data="$1"
  curl -fs -X POST "${SERVER_URL}/api/machines/ingest" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${AGENT_TOKEN}" \
    -d "$data" >/dev/null 2>&1
}

append_buffer() {
  local data="$1"
  local one_liner
  one_liner=$(echo "$data" | tr -d '\r\n' | tr -s ' ')
  [ -z "$one_liner" ] && return
  echo "$one_liner" >> "$BUFFER_FILE"
  if [ -f "$BUFFER_FILE" ]; then
    local line_count
    line_count=$(wc -l < "$BUFFER_FILE" 2>/dev/null || echo 0)
    if [ "$line_count" -gt 500 ]; then
      local tmp_file="${BUFFER_FILE}.tmp"
      tail -n 500 "$BUFFER_FILE" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$BUFFER_FILE"
    fi
  fi
}

flush_buffer() {
  while [ -f "$BUFFER_FILE" ] && [ -s "$BUFFER_FILE" ]; do
    local first_line
    first_line=$(head -n 1 "$BUFFER_FILE" 2>/dev/null)
    if [ -z "$first_line" ]; then
      local tmp_file="${BUFFER_FILE}.tmp"
      tail -n +2 "$BUFFER_FILE" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$BUFFER_FILE"
      continue
    fi

    if send_payload "$first_line"; then
      local tmp_file="${BUFFER_FILE}.tmp"
      tail -n +2 "$BUFFER_FILE" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$BUFFER_FILE"
    else
      break
    fi
  done
}

echo "Starting Srevox Machine Ingestion Loop to ${SERVER_URL}..."
PREV_NET_STATS=($(get_net_bytes))
PREV_NET_RX=${PREV_NET_STATS[0]:-0}
PREV_NET_TX=${PREV_NET_STATS[1]:-0}
PREV_NET_TIME=$(date +%s)

while true; do
  flush_buffer

  NOW_NET_TIME=$(date +%s)
  NOW_NET_STATS=($(get_net_bytes))
  CURR_NET_RX=${NOW_NET_STATS[0]:-0}
  CURR_NET_TX=${NOW_NET_STATS[1]:-0}

  TIME_DELTA=$((NOW_NET_TIME - PREV_NET_TIME))
  [ "$TIME_DELTA" -le 0 ] && TIME_DELTA=1

  DIFF_RX=$((CURR_NET_RX - PREV_NET_RX))
  DIFF_TX=$((CURR_NET_TX - PREV_NET_TX))
  [ "$DIFF_RX" -lt 0 ] && DIFF_RX=0
  [ "$DIFF_TX" -lt 0 ] && DIFF_TX=0

  CALC_RX_SEC=$((DIFF_RX / TIME_DELTA))
  CALC_TX_SEC=$((DIFF_TX / TIME_DELTA))

  PREV_NET_RX=$CURR_NET_RX
  PREV_NET_TX=$CURR_NET_TX
  PREV_NET_TIME=$NOW_NET_TIME

  PAYLOAD=$(get_metrics_json "$CALC_RX_SEC" "$CALC_TX_SEC")
  if ! send_payload "$PAYLOAD"; then
    append_buffer "$PAYLOAD"
  fi
  sleep 10
done
EOF

chmod +x /tmp/srevox-collector.sh

# Install executable
if command -v sudo &>/dev/null; then
  sudo cp /tmp/srevox-collector.sh "${INSTALL_DIR}/srevox-collector"
  sudo chmod +x "${INSTALL_DIR}/srevox-collector"
else
  cp /tmp/srevox-collector.sh "${INSTALL_DIR}/srevox-collector"
  chmod +x "${INSTALL_DIR}/srevox-collector"
fi

rm -f /tmp/srevox-collector.sh

# Check if systemd exists
if command -v systemctl &>/dev/null; then
  SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
  
  if command -v sudo &>/dev/null; then
    cat <<SERVICE | sudo tee "${SERVICE_PATH}" >/dev/null
[Unit]
Description=Srevox Host Machine Monitoring Agent
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/srevox-collector "${SERVER_URL}" "${AGENT_TOKEN}"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
    sudo systemctl daemon-reload
    sudo systemctl enable "${SERVICE_NAME}"
    sudo systemctl restart "${SERVICE_NAME}"
  else
    cat <<SERVICE > "${SERVICE_PATH}"
[Unit]
Description=Srevox Host Machine Monitoring Agent
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/srevox-collector "${SERVER_URL}" "${AGENT_TOKEN}"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    systemctl restart "${SERVICE_NAME}"
  fi

  echo "✅ Srevox Agent systemd service installed & started successfully!"
  echo "Check status via: systemctl status ${SERVICE_NAME}"
else
  echo "⚠️ systemd not found. Running collector in background Nohup mode..."
  nohup ${INSTALL_DIR}/srevox-collector "${SERVER_URL}" "${AGENT_TOKEN}" > /var/log/srevox-agent.log 2>&1 &
  echo "✅ Srevox Agent started in background!"
fi
