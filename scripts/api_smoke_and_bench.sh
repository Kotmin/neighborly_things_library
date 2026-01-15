#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# Config
# ---------------------------
BASE_URL="${BASE_URL:-http://localhost:3000}"
HOST_HEADER="${HOST_HEADER:-}" # e.g. "neighborly.local" (for ingress). Leave empty for localhost.
CURL="${CURL:-curl}"

# For load test
CONCURRENCY="${CONCURRENCY:-10}"
REQUESTS="${REQUESTS:-200}"

# ---------------------------
# Helpers
# ---------------------------
curl_json() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  local args=(
    -sS
    -X "$method"
    "$BASE_URL$url"
    -H "Content-Type: application/json"
  )

  if [[ -n "$HOST_HEADER" ]]; then
    args+=(-H "Host: $HOST_HEADER")
  fi

  if [[ -n "$data" ]]; then
    args+=(-d "$data")
  fi

  "${CURL}" "${args[@]}"
}

expect_status() {
  local expected="$1"
  local method="$2"
  local url="$3"
  local data="${4:-}"

  local args=(
    -sS
    -o /tmp/resp_body.json
    -w "%{http_code}"
    -X "$method"
    "$BASE_URL$url"
    -H "Content-Type: application/json"
  )

  if [[ -n "$HOST_HEADER" ]]; then
    args+=(-H "Host: $HOST_HEADER")
  fi

  if [[ -n "$data" ]]; then
    args+=(-d "$data")
  fi

  local code
  code="$("${CURL}" "${args[@]}")"

  if [[ "$code" != "$expected" ]]; then
    echo "Expected HTTP $expected but got $code for $method $url"
    echo "Response body:"
    cat /tmp/resp_body.json || true
    echo
    exit 1
  fi
}

json_get_field() {
  local field="$1"
  ruby -r json -e "j=JSON.parse(STDIN.read); v=j['$field']; puts(v.nil? ? '' : v)"
}

json_get_first_id() {
  ruby -r json -e "j=JSON.parse(STDIN.read); puts(j.is_a?(Array) && j[0] ? j[0]['id'] : '')"
}

now_ms() {
  ruby -e "puts((Time.now.to_f * 1000).to_i)"
}

# ---------------------------
# Smoke tests
# ---------------------------
echo "== Smoke: /healthz"
expect_status 200 GET /healthz

echo "== Smoke: create item"
ITEM_PAYLOAD='{"item":{"name":"Projector","category":"Electronics","description":"HD projector","condition":"good"}}'
expect_status 201 POST /api/items "$ITEM_PAYLOAD"

echo "== Smoke: list items"
expect_status 200 GET /api/items
ITEM_ID="$(curl_json GET /api/items | json_get_first_id)"
if [[ -z "$ITEM_ID" ]]; then
  echo "Could not read an item id from /api/items"
  exit 1
fi
echo "Using ITEM_ID=$ITEM_ID"

echo "== Smoke: borrow item (should be 201)"
BORROW_PAYLOAD="$(ruby -e "puts({item_id: $ITEM_ID, borrower_name: 'Alice'}.to_json)")"
expect_status 201 POST /api/loans "$BORROW_PAYLOAD"

echo "== Smoke: borrow same item again (should be 409)"
BORROW2_PAYLOAD="$(ruby -e "puts({item_id: $ITEM_ID, borrower_name: 'Bob'}.to_json)")"
expect_status 409 POST /api/loans "$BORROW2_PAYLOAD"

echo "== Smoke: return item (should be 200)"
RETURN_PAYLOAD="$(ruby -e "puts({item_id: $ITEM_ID}.to_json)")"
expect_status 200 POST /api/returns "$RETURN_PAYLOAD"

echo "== Smoke: return again (should be 409)"
expect_status 409 POST /api/returns "$RETURN_PAYLOAD"

echo "Smoke tests: OK"
echo

# ---------------------------
# Mini benchmark (GET /healthz)
# ---------------------------
echo "== Bench: GET /healthz"
echo "Requests=$REQUESTS Concurrency=$CONCURRENCY"

start="$(now_ms)"

# naive worker pool using xargs -P
seq "$REQUESTS" | xargs -I{} -P "$CONCURRENCY" bash -lc \
  "curl -fsS ${HOST_HEADER:+-H \"Host: $HOST_HEADER\"} $BASE_URL/healthz >/dev/null" || {
    echo "Bench failed"
    exit 1
  }

end="$(now_ms)"
elapsed_ms="$((end - start))"

rps="$(ruby -e "ms=$elapsed_ms; req=$REQUESTS; puts((req / (ms/1000.0)).round(2))")"
echo "Elapsed: ${elapsed_ms}ms"
echo "Approx RPS: ${rps}"
echo "Bench: OK"
