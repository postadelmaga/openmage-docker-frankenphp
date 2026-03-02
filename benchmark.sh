#!/bin/bash

# ============================================================
# Ecommerce Performance Benchmark
# Compatibile con Maho e OpenMage
#
# Uso:
#   ./benchmark.sh [compose_dir] [cache_flush_cmd] [url]
#
# Esempi:
#   Maho:
#     ./benchmark.sh \
#       /mnt/sda1/maho-docker \
#       "docker compose exec app /app/maho cache:flush" \
#       "https://maho.127.0.0.1.nip.io/"
#
#   OpenMage:
#     ./benchmark.sh \
#       /mnt/sda1/openmage-docker \
#       "docker exec -w /app/public openmage_app ./vendor/bin/n98-magerun cache:flush" \
#       "https://openmage.127.0.0.1.nip.io/"
# ============================================================

COMPOSE_DIR="${1:-$(pwd)}"
CACHE_FLUSH_CMD="${2:-docker exec -w /app/public openmage_app ./vendor/bin/n98-magerun cache:flush}"
URL="${3:-https://openmage.127.0.0.1.nip.io/}"
RUNS=10
REPORT="benchmark.md"

COOKIE="om_frontend=4644358a243f9512b818e24d8b88e8c2"
UA="Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Mobile Safari/537.36"

CURL_OPTS=(
  -k -o /dev/null -s
  -w "%{time_namelookup} %{time_starttransfer} %{time_total} %{http_code}"
  -H "accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
  -H "accept-language: it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7"
  -b "$COOKIE"
  -H "dnt: 1"
  -H "priority: u=0, i"
  -H "user-agent: $UA"
)

# ---- colori terminale ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

sep() { echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"; }

flush_cache() {
  echo -e "${YELLOW}Flush cache...${RESET}"
  cd "$COMPOSE_DIR" && eval "$CACHE_FLUSH_CMD" > /dev/null 2>&1
  echo -e "${GREEN}✓ Cache svuotata${RESET}"
}

run_requests() {
  local label="$1"
  local phase="$2"
  local -a dns_arr=() ttfb_arr=() total_arr=() http_arr=()

  echo -e "\n${BOLD}${label}${RESET}"
  sep
  printf "  %-5s %-12s %-12s %-12s %s\n" "Run" "DNS (s)" "TTFB (s)" "Total (s)" "HTTP"
  sep

  for i in $(seq 1 $RUNS); do
    read -r dns ttfb total http <<< $(curl "${CURL_OPTS[@]}" "$URL")
    dns_arr+=($dns); ttfb_arr+=($ttfb); total_arr+=($total); http_arr+=($http)

    color=$GREEN
    (( $(awk "BEGIN {print ($total > 1.0)}") )) && color=$RED
    (( $(awk "BEGIN {print ($total > 0.5 && $total <= 1.0)}") )) && color=$YELLOW

    printf "  %-5s %-12s %-12s ${color}%-12s${RESET} %s\n" \
      "#$i" "$dns" "$ttfb" "$total" "$http"
    sleep 0.2
  done

  local stats
  stats=$(awk '
    BEGIN { n=0 }
    {
      n++
      sum_dns+=$1; sum_ttfb+=$2; sum_total+=$3
      if (n==1) { min_dns=$1; max_dns=$1; min_ttfb=$2; max_ttfb=$2; min_total=$3; max_total=$3 }
      if ($1 < min_dns)   min_dns=$1;   if ($1 > max_dns)   max_dns=$1
      if ($2 < min_ttfb)  min_ttfb=$2;  if ($2 > max_ttfb)  max_ttfb=$2
      if ($3 < min_total) min_total=$3; if ($3 > max_total) max_total=$3
    }
    END {
      printf "%.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f\n",
        sum_dns/n, min_dns, max_dns,
        sum_ttfb/n, min_ttfb, max_ttfb,
        sum_total/n, min_total, max_total
    }
  ' <(for i in "${!dns_arr[@]}"; do echo "${dns_arr[$i]} ${ttfb_arr[$i]} ${total_arr[$i]}"; done))

  read avg_dns min_dns max_dns avg_ttfb min_ttfb max_ttfb avg_total min_total max_total <<< "$stats"

  sep
  printf "  %-10s %-12s %-12s %s\n" "" "DNS (s)" "TTFB (s)" "Total (s)"
  printf "  %-10s %-12s %-12s %s\n" "avg" "$avg_dns" "$avg_ttfb" "$avg_total"
  printf "  %-10s %-12s %-12s %s\n" "min" "$min_dns" "$min_ttfb" "$min_total"
  printf "  %-10s %-12s %-12s %s\n" "max" "$max_dns" "$max_ttfb" "$max_total"
  sep

  # ---- sezione markdown ----
  cat >> "$REPORT" <<EOF

### $label

| # | DNS (s) | TTFB (s) | Total (s) | Status |
|--:|--------:|---------:|----------:|:------:|
EOF

  for i in "${!dns_arr[@]}"; do
    status="✅"
    (( $(awk "BEGIN {print (${total_arr[$i]} > 1.0)}") )) && status="🔴"
    (( $(awk "BEGIN {print (${total_arr[$i]} > 0.5 && ${total_arr[$i]} <= 1.0)}") )) && status="🟡"
    echo "| $((i+1)) | \`${dns_arr[$i]}\` | \`${ttfb_arr[$i]}\` | \`${total_arr[$i]}\` | $status |" >> "$REPORT"
  done

  cat >> "$REPORT" <<EOF

|          |    DNS (s) |   TTFB (s) | **Total (s)** |
|---------:|-----------:|-----------:|--------------:|
| **avg**  | \`$avg_dns\`  | \`$avg_ttfb\`  | **\`$avg_total\`**  |
| **min**  | \`$min_dns\`  | \`$min_ttfb\`  | **\`$min_total\`**  |
| **max**  | \`$max_dns\`  | \`$max_ttfb\`  | **\`$max_total\`**  |

EOF

  eval "AVG_TOTAL_${phase}=$avg_total"
  eval "AVG_TTFB_${phase}=$avg_ttfb"
  eval "MIN_TOTAL_${phase}=$min_total"
  eval "MAX_TOTAL_${phase}=$max_total"
}

# ============================================================

echo -e "\n${BOLD}${CYAN}=== ECOMMERCE PERFORMANCE BENCHMARK ===${RESET}"
echo -e "URL: $URL  |  Runs: $RUNS  |  Report: $REPORT\n"

# ---- inizializza report ----
cat > "$REPORT" <<EOF
# 🚀 Ecommerce Performance Benchmark

|             |                                      |
|-------------|--------------------------------------|
| **URL**     | \`$URL\`                               |
| **Data**    | $(date '+%d %B %Y — %H:%M:%S')       |
| **Runs**    | $RUNS per fase                       |
| **Legenda** | ✅ < 0.5s &nbsp; 🟡 0.5–1.0s &nbsp; 🔴 > 1.0s |

---

## Risultati per fase

EOF

# ---- FASE 1: cold start ----
echo -e "\n${BOLD}[1/3] Cold start${RESET}"
flush_cache
run_requests "⚡ Fase 1 — Cold start (cache svuotata)" "1"

# ---- FASE 2: warm cache ----
echo -e "\n${BOLD}[2/3] Warm cache${RESET}"
run_requests "🔥 Fase 2 — Warm cache (popolata dalla fase 1)" "2"

# ---- FASE 3: flush + warmup ----
echo -e "\n${BOLD}[3/3] Post-flush con warmup${RESET}"
flush_cache
curl "${CURL_OPTS[@]}" "$URL" > /dev/null 2>&1
echo -e "${GREEN}✓ Warmup eseguito${RESET}"
run_requests "🌡️  Fase 3 — Post-flush con warmup iniziale" "3"

# ---- RIEPILOGO TERMINALE ----
echo -e "\n${BOLD}${CYAN}=== RIEPILOGO ===${RESET}"
sep
printf "  %-45s %s\n" "Fase" "Avg Total (s)"
sep
printf "  %-45s %s\n" "⚡ Cold start"             "$AVG_TOTAL_1"
printf "  %-45s %s\n" "🔥 Warm cache"             "$AVG_TOTAL_2"
printf "  %-45s %s\n" "🌡️  Post-flush con warmup"  "$AVG_TOTAL_3"
sep

# ---- RIEPILOGO MARKDOWN ----
improvement=$(awk "BEGIN {
  diff = $AVG_TOTAL_1 - $AVG_TOTAL_2
  pct  = (diff / $AVG_TOTAL_1) * 100
  printf \"%.1f\", pct
}")

cat >> "$REPORT" <<EOF
---

## 📋 Riepilogo

| Fase                      | Avg TTFB (s) | Avg Total (s)       | Min (s)          | Max (s)          |
|---------------------------|-------------:|--------------------:|-----------------:|-----------------:|
| ⚡ Cold start             | \`$AVG_TTFB_1\`  | **\`$AVG_TOTAL_1\`**    | \`$MIN_TOTAL_1\`     | \`$MAX_TOTAL_1\`     |
| 🔥 Warm cache             | \`$AVG_TTFB_2\`  | **\`$AVG_TOTAL_2\`**    | \`$MIN_TOTAL_2\`     | \`$MAX_TOTAL_2\`     |
| 🌡️  Post-flush con warmup | \`$AVG_TTFB_3\`  | **\`$AVG_TOTAL_3\`**    | \`$MIN_TOTAL_3\`     | \`$MAX_TOTAL_3\`     |

> 💡 La cache riduce il tempo di risposta del **${improvement}%** rispetto al cold start (Fase 2 vs Fase 1).

---
*Generato da benchmark.sh — $(date '+%Y-%m-%d %H:%M:%S')*
EOF

echo -e "\n${GREEN}Report salvato in: ${BOLD}${REPORT}${RESET}\n"