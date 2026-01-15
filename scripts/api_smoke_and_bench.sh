#!/usr/bin/env bash
set -euo pipefail

# ===========================
# Config
# ===========================
BASE_URL="${BASE_URL:-http://localhost:3000}"
HOST_HEADER="${HOST_HEADER:-}"     # e.g. "neighborly.local" for ingress. Leave empty for localhost.
CURL_BIN="${CURL_BIN:-curl}"
JQ_BIN="${JQ_BIN:-jq}"

# Benchmark (health endpoint)
CONCURRENCY="${CONCURRENCY:-10}"
REQUESTS="${REQUESTS:-200}"

# Seeding
SEED_ITEMS="${SEED_ITEMS:-0}"              # number of items to create before tests/bench
SEED_CONCURRENCY="${SEED_CONCURRENCY:-5}"  # parallelism for seeding writes

# Optional: benchmark list endpoint too
BENCH_LIST="${BENCH_LIST:-0}"              # 1 to enable list benchmark

# ===========================
# Preconditions
# ===========================
if ! command -v "$CURL_BIN" >/dev/null 2>&1; then
  echo "ERROR: curl not found (CURL_BIN=$CURL_BIN)"
  exit 1
fi

if ! command -v "$JQ_BIN" >/dev/null 2>&1; then
  echo "ERROR: jq not found (JQ_BIN=$JQ_BIN). Install jq or set JQ_BIN to its path."
  exit 1
fi

# ===========================
# Helpers
# ===========================
curl_args_common() {
  local -a args=(-sS)
  if [[ -n "$HOST_HEADER" ]]; then
    args+=(-H "Host: $HOST_HEADER")
  fi
  printf '%s\0' "${args[@]}"
}

# Writes body to /tmp/resp_body.json and echoes HTTP status code
http_request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"

  local -a args
  IFS=$'\0' read -r -d '' -a args < <(curl_args_common; printf '\0')

  args+=(
    -o /tmp/resp_body.json
    -w "%{http_code}"
    -X "$method"
    "${BASE_URL}${path}"
  )

  if [[ -n "$data" ]]; then
    args+=(-H "Content-Type: application/json" -d "$data")
  fi

  "$CURL_BIN" "${args[@]}"
}

expect_status() {
  local expected="$1"
  local method="$2"
  local path="$3"
  local data="${4:-}"

  local code
  code="$(http_request "$method" "$path" "$data")"

  if [[ "$code" != "$expected" ]]; then
    echo "FAIL: Expected HTTP $expected but got $code for $method $path"
    echo "Response body:"
    cat /tmp/resp_body.json || true
    echo
    exit 1
  fi
}

json_file_get() {
  local jq_filter="$1"
  "$JQ_BIN" -r "$jq_filter" /tmp/resp_body.json
}

ms_now() {
  if date +%s%3N >/dev/null 2>&1; then
    date +%s%3N
  else
    echo "$(( $(date +%s) * 1000 ))"
  fi
}

bench_endpoint() {
  local label="$1"
  local url_path="$2"

  echo "== Bench: $label"
  echo "Requests=$REQUESTS Concurrency=$CONCURRENCY"

  local start_ms end_ms elapsed_ms rps
  start_ms="$(ms_now)"

  export BASE_URL HOST_HEADER CURL_BIN url_path
  seq "$REQUESTS" | xargs -I{} -P "$CONCURRENCY" bash -lc '
    set -euo pipefail
    args=(-fsS)
    if [[ -n "${HOST_HEADER:-}" ]]; then
      args+=(-H "Host: ${HOST_HEADER}")
    fi
    "${CURL_BIN}" "${args[@]}" "${BASE_URL}${url_path}" >/dev/null
  ' || {
    echo "Bench failed"
    exit 1
  }

  end_ms="$(ms_now)"
  elapsed_ms="$((end_ms - start_ms))"
  rps="$("$JQ_BIN" -n --argjson req "$REQUESTS" --argjson ms "$elapsed_ms" \
    '$req / ($ms/1000) | (.*100 | round)/100'
  )"

  echo "Elapsed: ${elapsed_ms}ms"
  echo "Approx RPS: ${rps}"
  echo
}

seed_items() {
  local n="$1"
  local seed_conc="$2"

  if [[ "$n" -le 0 ]]; then
    return 0
  fi

  echo "== Seed: creating $n items (concurrency=$seed_conc)"

  export BASE_URL HOST_HEADER CURL_BIN JQ_BIN

  seq "$n" | xargs -I{} -P "$seed_conc" bash -lc '
    set -euo pipefail
    i="{}"

    payload="$("${JQ_BIN}" -n \
      --arg name "Seed Item ${i}" \
      --arg category "Seed" \
      --arg description "Generated item ${i}" \
      --arg condition "good" \
      "{item:{name:\$name,category:\$category,description:\$description,condition:\$condition}}"
    )"

    args=(-sS -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/items" -H "Content-Type: application/json" -d "${payload}")
    if [[ -n "${HOST_HEADER:-}" ]]; then
      args+=(-H "Host: ${HOST_HEADER}")
    fi

    code="$("${CURL_BIN}" "${args[@]}")"
    if [[ "$code" != "201" ]]; then
      echo "Seed failed for item ${i}: HTTP ${code}"
      exit 1
    fi
  ' || {
    echo "Seeding failed"
    exit 1
  }

  echo "Seed: OK"
  echo
}

# ===========================
# Seed data (optional)
# ===========================
seed_items "$SEED_ITEMS" "$SEED_CONCURRENCY"

# ===========================
# Smoke tests
# ===========================
echo "== Smoke: /healthz"
expect_status 200 GET /healthz

echo "== Smoke: create item"
ITEM_PAYLOAD="$("$JQ_BIN" -n \
  --arg name "Projector" \
  --arg category "Electronics" \
  --arg description "HD projector" \
  --arg condition "good" \
  '{item:{name:$name,category:$category,description:$description,condition:$condition}}'
)"
expect_status 201 POST /api/items "$ITEM_PAYLOAD"

echo "== Smoke: list items"
expect_status 200 GET /api/items
ITEM_ID="$(json_file_get '.[0].id // empty')"
if [[ -z "$ITEM_ID" ]]; then
  echo "FAIL: Could not read an item id from /api/items"
  echo "Body:"
  cat /tmp/resp_body.json || true
  exit 1
fi
echo "Using ITEM_ID=$ITEM_ID"

echo "== Smoke: borrow item (should be 201)"
BORROW_PAYLOAD="$("$JQ_BIN" -n --argjson item_id "$ITEM_ID" --arg borrower_name "Alice" \
  '{item_id:$item_id, borrower_name:$borrower_name}'
)"
expect_status 201 POST /api/loans "$BORROW_PAYLOAD"

echo "== Smoke: borrow same item again (should be 409)"
BORROW2_PAYLOAD="$("$JQ_BIN" -n --argjson item_id "$ITEM_ID" --arg borrower_name "Bob" \
  '{item_id:$item_id, borrower_name:$borrower_name}'
)"
expect_status 409 POST /api/loans "$BORROW2_PAYLOAD"

echo "== Smoke: return item (should be 200)"
RETURN_PAYLOAD="$("$JQ_BIN" -n --argjson item_id "$ITEM_ID" '{item_id:$item_id}')"
expect_status 200 POST /api/returns "$RETURN_PAYLOAD"

echo "== Smoke: return again (should be 409)"
expect_status 409 POST /api/returns "$RETURN_PAYLOAD"

echo "Smoke tests: OK"
echo

# ===========================
# Benchmarks
# ===========================
bench_endpoint "GET /healthz" "/healthz"

if [[ "$BENCH_LIST" == "1" ]]; then
  bench_endpoint "GET /api/items" "/api/items"
fi
