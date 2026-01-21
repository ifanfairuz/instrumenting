#!/bin/bash

# Traffic generator for testing OpenTelemetry instrumentation
# Usage: ./generate-traffic.sh [duration_in_seconds]

DURATION=${1:-60}  # Default: 60 seconds
BASE_URL=${2:-http://localhost:3000}

echo "Generating traffic to $BASE_URL for $DURATION seconds..."
echo "Press Ctrl+C to stop"
echo ""

START_TIME=$(date +%s)
REQUEST_COUNT=0
ERROR_COUNT=0

# Function to make requests
make_requests() {
  while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $DURATION ]; then
      break
    fi

    # Random user ID
    USER_ID=$((RANDOM % 100 + 1))

    # Random resource name
    RESOURCES=("products" "orders" "inventory" "analytics" "reports")
    RESOURCE=${RESOURCES[$RANDOM % ${#RESOURCES[@]}]}

    # Make different types of requests with varying probabilities
    RAND=$((RANDOM % 100))

    if [ $RAND -lt 40 ]; then
      # 40% - Get user
      curl -s -w "%{http_code}" -o /dev/null "$BASE_URL/user/$USER_ID" > /tmp/status.txt
    elif [ $RAND -lt 70 ]; then
      # 30% - Get resource
      curl -s -w "%{http_code}" -o /dev/null "$BASE_URL/api/$RESOURCE" > /tmp/status.txt
    elif [ $RAND -lt 85 ]; then
      # 15% - Process items
      curl -s -w "%{http_code}" -o /dev/null -X POST "$BASE_URL/api/process" \
        -H "Content-Type: application/json" \
        -d "{\"items\": [\"item1\", \"item2\", \"item3\"]}" > /tmp/status.txt
    elif [ $RAND -lt 95 ]; then
      # 10% - Health check
      curl -s -w "%{http_code}" -o /dev/null "$BASE_URL/" > /tmp/status.txt
    elif [ $RAND -lt 98 ]; then
      # 3% - Slow endpoint
      curl -s -w "%{http_code}" -o /dev/null "$BASE_URL/slow" > /tmp/status.txt
    else
      # 2% - Error endpoint
      curl -s -w "%{http_code}" -o /dev/null "$BASE_URL/error" > /tmp/status.txt
    fi

    STATUS=$(cat /tmp/status.txt)
    REQUEST_COUNT=$((REQUEST_COUNT + 1))

    if [ "$STATUS" != "200" ]; then
      ERROR_COUNT=$((ERROR_COUNT + 1))
    fi

    # Print progress every 10 requests
    if [ $((REQUEST_COUNT % 10)) -eq 0 ]; then
      SUCCESS_COUNT=$((REQUEST_COUNT - ERROR_COUNT))
      printf "\rRequests: %d | Success: %d | Errors: %d | Elapsed: %ds" \
        $REQUEST_COUNT $SUCCESS_COUNT $ERROR_COUNT $ELAPSED
    fi

    # Random delay between requests (100-500ms)
    sleep 0.$((RANDOM % 4 + 1))
  done
}

# Run traffic generator
make_requests

# Final stats
echo ""
echo ""
echo "===================="
echo "Traffic Generation Complete"
echo "===================="
echo "Total Requests: $REQUEST_COUNT"
echo "Successful: $((REQUEST_COUNT - ERROR_COUNT))"
echo "Errors: $ERROR_COUNT"
echo "Duration: ${DURATION}s"
echo "Avg Rate: $((REQUEST_COUNT / DURATION)) req/s"
echo ""
echo "View traces in Grafana: http://localhost:3000"
echo "  1. Go to Explore"
echo "  2. Select Tempo datasource"
echo "  3. Search for service: nodejs-example"

# Cleanup
rm -f /tmp/status.txt
