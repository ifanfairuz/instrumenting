# Node.js OpenTelemetry Auto-Instrumentation Example

A complete example of a Node.js Express application instrumented with OpenTelemetry using **only environment variables** - no code changes required.

## Quick Start

### 1. Start the Observability Stack

From the root of this repository:

```bash
cd ../..
docker compose up -d
```

### 2. Install Dependencies

```bash
cd examples/nodejs-example
npm install
```

### 3. Set Environment Variables

```bash
# Copy the example env file
cp .env.example .env

# Or export directly
export OTEL_SERVICE_NAME=nodejs-example
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4320
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
```

### 4. Run the Application

```bash
# With auto-instrumentation
npm start

# Or manually
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

### 5. Generate Traffic

```bash
# Health check
curl http://localhost:3000/

# Fetch user data
curl http://localhost:3000/user/123

# External API call
curl http://localhost:3000/api/products

# Process items
curl -X POST http://localhost:3000/api/process \
  -H "Content-Type: application/json" \
  -d '{"items": ["item1", "item2", "item3"]}'

# Slow endpoint
curl http://localhost:3000/slow

# Error endpoint (for testing error tracking)
curl http://localhost:3000/error
```

### 6. View Telemetry in Grafana

1. Open Grafana: http://localhost:3000
2. Login: `admin` / `admin`
3. Go to **Explore**
4. Select **Tempo** datasource
5. Click **Search** tab
6. Filter by service: `nodejs-example`
7. View traces, then click to see:
   - Span details and timing
   - Related logs (click "Logs" button)
   - Related metrics

## Running with Docker

### Build and Run

```bash
# Build the image
docker build -t nodejs-example .

# Run with the observability network
docker run -d \
  --name nodejs-example \
  --network instrumenting_observability \
  -p 3000:3000 \
  -e OTEL_SERVICE_NAME=nodejs-example \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4317 \
  -e OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
  -e OTEL_TRACES_EXPORTER=otlp \
  -e OTEL_METRICS_EXPORTER=otlp \
  -e OTEL_LOGS_EXPORTER=otlp \
  nodejs-example
```

### Using Docker Compose

```bash
# Start the observability stack first
cd ../..
docker compose up -d

# Then start the Node.js app
cd examples/nodejs-example
docker compose -f docker-compose.example.yml up -d
```

## Available Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| GET | `/user/:id` | Fetch user by ID (simulated DB query) |
| GET | `/api/:resource` | Fetch external resource (simulated API call) |
| POST | `/api/process` | Process items (accepts JSON array) |
| GET | `/slow` | Slow endpoint (2 second delay) |
| GET | `/error` | Trigger an error (for testing) |

## What Gets Instrumented Automatically?

Without any code changes, the auto-instrumentation captures:

### Traces
- HTTP requests and responses
- Express route handling
- Async operations
- Error tracking

### Metrics
- HTTP request duration
- HTTP request count
- Active connections
- Error rates

### Logs
- Console.log output
- Error logs
- Request logs

## Customization

### Adding Custom Attributes

You can add custom attributes to spans in your code:

```javascript
const { trace } = require('@opentelemetry/api');

app.get('/custom', (req, res) => {
  const span = trace.getActiveSpan();
  if (span) {
    span.setAttribute('user.id', '12345');
    span.setAttribute('custom.data', 'value');
  }
  res.json({ message: 'Custom attributes added' });
});
```

### Creating Custom Spans

```javascript
const { trace } = require('@opentelemetry/api');

const tracer = trace.getTracer('my-tracer');

app.get('/operation', async (req, res) => {
  const span = tracer.startSpan('custom-operation');

  try {
    // Your operation
    await doSomething();
    span.setStatus({ code: 1 }); // OK
  } catch (error) {
    span.setStatus({ code: 2, message: error.message }); // ERROR
    span.recordException(error);
    throw error;
  } finally {
    span.end();
  }

  res.json({ done: true });
});
```

## Troubleshooting

### Enable Debug Logging

```bash
OTEL_LOG_LEVEL=debug npm start
```

### Check if Telemetry is Being Sent

Watch Alloy logs:

```bash
docker compose logs -f alloy
```

### Verify Endpoints

Check that services are accessible:

```bash
# Alloy HTTP endpoint
curl http://localhost:4320

# Alloy gRPC endpoint (should refuse HTTP)
curl http://localhost:4319
```

## Load Testing

Generate continuous traffic for testing:

```bash
# Install Apache Bench
# macOS: brew install httpd
# Ubuntu: sudo apt-get install apache2-utils

# Generate 1000 requests with 10 concurrent connections
ab -n 1000 -c 10 http://localhost:3000/user/123
```

Or use a simple bash loop:

```bash
while true; do
  curl -s http://localhost:3000/user/$((RANDOM % 100)) > /dev/null
  curl -s http://localhost:3000/api/product-$((RANDOM % 10)) > /dev/null
  sleep 0.5
done
```

## Production Considerations

### Sampling

For high-traffic production, reduce sampling:

```bash
# Sample 10% of traces
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.1
```

### Resource Attributes

Add production metadata:

```bash
export OTEL_RESOURCE_ATTRIBUTES="
deployment.environment=production,
service.version=${APP_VERSION},
service.namespace=backend,
cloud.provider=aws,
cloud.region=${AWS_REGION},
k8s.pod.name=${POD_NAME}
"
```

### Performance

The auto-instrumentation has minimal overhead:
- ~1-2% CPU overhead
- ~10-20MB additional memory
- Async operations, no blocking

## References

- [OpenTelemetry Node.js Documentation](https://opentelemetry.io/docs/languages/js/)
- [Auto-Instrumentation Package](https://github.com/open-telemetry/opentelemetry-js-contrib/tree/main/metapackages/auto-instrumentations-node)
- [Environment Variables Reference](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)
