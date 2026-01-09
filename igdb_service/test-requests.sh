#!/bin/bash

BASE_URL="http://localhost:61000"

echo "=== Test 1: Health Check ==="
curl -s "$BASE_URL/health" | jq

echo -e "\n=== Test 2: Valid Steam IDs ==="
curl -s -X POST "$BASE_URL/api/games" \
  -H "Content-Type: application/json" \
  -d '{"steamIds": [730, 570, 440], "forceRefresh": true,"language": "zh-CN"}' | jq

# echo -e "\n=== Test 3: Cache Hit (run twice) ==="
# curl -s -X POST "$BASE_URL/api/games" \
#   -H "Content-Type: application/json" \
#   -d '{"steamIds": [730]}' | jq

# echo -e "\n=== Test 4: Force Refresh ==="
# curl -s -X POST "$BASE_URL/api/games" \
#   -H "Content-Type: application/json" \
#   -d '{"steamIds": [730], "forceRefresh": true}' | jq

# echo -e "\n=== Test 5: Invalid Steam ID ==="
# curl -s -X POST "$BASE_URL/api/games" \
#   -H "Content-Type: application/json" \
#   -d '{"steamIds": [999999999]}' | jq

# echo -e "\n=== Test 6: Empty Array ==="
# curl -s -X POST "$BASE_URL/api/games" \
#   -H "Content-Type: application/json" \
#   -d '{"steamIds": []}' | jq

# echo -e "\n=== Test 7: Invalid Request (missing steamIds) ==="
# curl -s -X POST "$BASE_URL/api/games" \
#   -H "Content-Type: application/json" \
#   -d '{}' | jq

# echo -e "\n=== Test 8: 404 Route ==="
# curl -s "$BASE_URL/invalid" | jq
