# Node.js Auto-Instrumentation with OpenTelemetry

This guide shows how to instrument a Node.js application using OpenTelemetry auto-instrumentation **without any code changes** - only environment variables.

## Overview

OpenTelemetry provides automatic instrumentation for Node.js that can be enabled via the `@opentelemetry/auto-instrumentations-node` package. You can configure everything using environment variables.

## Quick Start

### 1. Install Dependencies

```bash
npm install --save @opentelemetry/api
npm install --save @opentelemetry/auto-instrumentations-node
```

### 2. Set Environment Variables

```bash
# Service name
export OTEL_SERVICE_NAME="my-nodejs-app"

# OTLP Exporter endpoint (Alloy)
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4320"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"

# What to export
export OTEL_TRACES_EXPORTER="otlp"
export OTEL_METRICS_EXPORTER="otlp"
export OTEL_LOGS_EXPORTER="otlp"

# Resource attributes
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.version=1.0.0"

# Log level
export OTEL_LOG_LEVEL="info"
```

### 3. Run Your Application

```bash
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

That's it! Your application is now instrumented with traces, metrics, and logs.

## Complete Example

### Example Application (app.js)

```javascript
const express = require('express');
const app = express();
const port = 3000;

// Simulate database call
async function queryDatabase(userId) {
  await new Promise(resolve => setTimeout(resolve, Math.random() * 100));
  return { id: userId, name: 'User ' + userId };
}

// Simulate external API call
async function fetchExternalData() {
  await new Promise(resolve => setTimeout(resolve, Math.random() * 200));
  return { data: 'external data' };
}

app.get('/', (req, res) => {
  res.json({ message: 'Hello World!' });
});

app.get('/user/:id', async (req, res) => {
  const userId = req.params.id;
  const user = await queryDatabase(userId);
  res.json(user);
});

app.get('/api/data', async (req, res) => {
  const data = await fetchExternalData();
  res.json(data);
});

app.get('/error', (req, res) => {
  throw new Error('Intentional error for testing');
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
```

### package.json

```json
{
  "name": "nodejs-otel-example",
  "version": "1.0.0",
  "description": "Node.js app with OpenTelemetry auto-instrumentation",
  "main": "app.js",
  "scripts": {
    "start": "node --require @opentelemetry/auto-instrumentations-node/register app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "@opentelemetry/api": "^1.9.0",
    "@opentelemetry/auto-instrumentations-node": "^0.50.0"
  }
}
```

### .env File

Create a `.env` file with your configuration:

```bash
# Service identification
OTEL_SERVICE_NAME=my-nodejs-app
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.version=1.0.0,team=backend

# OTLP Exporter configuration
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4320
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# Enable all signals
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp

# Sampling (1.0 = 100% of traces)
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=1.0

# Metric export interval (milliseconds)
OTEL_METRIC_EXPORT_INTERVAL=60000

# Log level
OTEL_LOG_LEVEL=info

# Propagators (for distributed tracing)
OTEL_PROPAGATORS=tracecontext,baggage
```

Then run with:

```bash
# Load .env file and run
export $(cat .env | xargs) && npm start
```

## Docker Example

### Dockerfile

```dockerfile
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Expose application port
EXPOSE 3000

# Run with auto-instrumentation
CMD ["node", "--require", "@opentelemetry/auto-instrumentations-node/register", "app.js"]
```

### docker-compose.yml

Add your Node.js service to the observability stack:

```yaml
services:
  # Your Node.js application
  nodejs-app:
    build: ./my-nodejs-app
    ports:
      - "3000:3000"
    environment:
      # Service identification
      - OTEL_SERVICE_NAME=my-nodejs-app
      - OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.version=1.0.0

      # OTLP Exporter (send to Alloy in same network)
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4317
      - OTEL_EXPORTER_OTLP_PROTOCOL=grpc

      # Enable all signals
      - OTEL_TRACES_EXPORTER=otlp
      - OTEL_METRICS_EXPORTER=otlp
      - OTEL_LOGS_EXPORTER=otlp

      # Sampling
      - OTEL_TRACES_SAMPLER=parentbased_traceidratio
      - OTEL_TRACES_SAMPLER_ARG=1.0

      # Propagators
      - OTEL_PROPAGATORS=tracecontext,baggage

      # Log level
      - OTEL_LOG_LEVEL=info
    networks:
      - observability
    depends_on:
      - alloy

  # ... rest of your observability stack (grafana, tempo, loki, etc.)

networks:
  observability:
    driver: bridge
```

## Environment Variables Reference

### Service Identification

| Variable | Description | Example |
|----------|-------------|---------|
| `OTEL_SERVICE_NAME` | Name of your service | `my-nodejs-app` |
| `OTEL_RESOURCE_ATTRIBUTES` | Additional attributes | `env=prod,version=1.0` |

### OTLP Exporter Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP endpoint URL | `http://localhost:4320` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | Protocol to use | `http/protobuf` or `grpc` |
| `OTEL_EXPORTER_OTLP_HEADERS` | Custom headers | `api-key=secret` |
| `OTEL_EXPORTER_OTLP_TIMEOUT` | Request timeout (ms) | `10000` |

### Signal-Specific Endpoints (Optional)

If you want to send different signals to different endpoints:

```bash
# Traces
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4320/v1/traces
OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf

# Metrics
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://localhost:4320/v1/metrics
OTEL_EXPORTER_OTLP_METRICS_PROTOCOL=http/protobuf

# Logs
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://localhost:4320/v1/logs
OTEL_EXPORTER_OTLP_LOGS_PROTOCOL=http/protobuf
```

### Exporter Selection

| Variable | Description | Values |
|----------|-------------|--------|
| `OTEL_TRACES_EXPORTER` | Trace exporter | `otlp`, `console`, `none` |
| `OTEL_METRICS_EXPORTER` | Metric exporter | `otlp`, `console`, `none` |
| `OTEL_LOGS_EXPORTER` | Log exporter | `otlp`, `console`, `none` |

### Sampling Configuration

| Variable | Description | Values |
|----------|-------------|--------|
| `OTEL_TRACES_SAMPLER` | Sampling strategy | `always_on`, `always_off`, `traceidratio`, `parentbased_always_on`, `parentbased_traceidratio` |
| `OTEL_TRACES_SAMPLER_ARG` | Sampler argument | `0.1` (10%), `1.0` (100%) |

### Propagation

| Variable | Description | Values |
|----------|-------------|--------|
| `OTEL_PROPAGATORS` | Context propagators | `tracecontext`, `baggage`, `b3`, `b3multi`, `jaeger` |

### Instrumentation Control

| Variable | Description | Values |
|----------|-------------|--------|
| `OTEL_NODE_DISABLED_INSTRUMENTATIONS` | Disable specific instrumentations | `http,fs` |
| `OTEL_LOG_LEVEL` | SDK log level | `debug`, `info`, `warn`, `error` |

## Testing Your Instrumentation

### 1. Start the Observability Stack

```bash
docker compose up -d
```

### 2. Run Your Node.js App

```bash
# Set environment variables
export OTEL_SERVICE_NAME="my-nodejs-app"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4320"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_TRACES_EXPORTER="otlp"
export OTEL_METRICS_EXPORTER="otlp"
export OTEL_LOGS_EXPORTER="otlp"

# Run with auto-instrumentation
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

### 3. Generate Traffic

```bash
# Make some requests
curl http://localhost:3000/
curl http://localhost:3000/user/123
curl http://localhost:3000/api/data
curl http://localhost:3000/error  # Test error tracking
```

### 4. View in Grafana

1. Open Grafana: http://localhost:3000
2. Login with `admin/admin`
3. Go to **Explore**
4. Select **Tempo** datasource
5. Search for traces from `my-nodejs-app`
6. Click on a trace to see:
   - Span details
   - Related logs (click "Logs for this span")
   - Related metrics

## Automatically Instrumented Libraries

The auto-instrumentation package automatically instruments:

- **HTTP**: `http`, `https`
- **Express**: Express.js framework
- **GraphQL**: GraphQL servers
- **gRPC**: gRPC clients and servers
- **MongoDB**: MongoDB client
- **MySQL**: MySQL/MySQL2 clients
- **PostgreSQL**: pg client
- **Redis**: Redis clients
- **AWS SDK**: AWS SDK v2 and v3
- **DNS**: DNS lookups
- **Net**: Network connections
- **And many more...**

See the full list: https://github.com/open-telemetry/opentelemetry-js-contrib/tree/main/metapackages/auto-instrumentations-node

## Production Considerations

### 1. Sampling

For high-traffic applications, use sampling to reduce overhead:

```bash
# Sample 10% of traces
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1
```

### 2. Batch Configuration

Adjust batch sizes for better performance:

```bash
# Batch span processor configuration
OTEL_BSP_MAX_QUEUE_SIZE=2048
OTEL_BSP_MAX_EXPORT_BATCH_SIZE=512
OTEL_BSP_SCHEDULE_DELAY=5000
```

### 3. Resource Attributes

Add useful metadata:

```bash
OTEL_RESOURCE_ATTRIBUTES="
deployment.environment=production,
service.version=1.2.3,
service.namespace=backend,
service.instance.id=${HOSTNAME},
cloud.provider=aws,
cloud.region=us-east-1,
k8s.pod.name=${POD_NAME},
k8s.namespace.name=${NAMESPACE}
"
```

### 4. Disable Unwanted Instrumentations

```bash
# Disable file system instrumentation if not needed
OTEL_NODE_DISABLED_INSTRUMENTATIONS=fs,dns
```

## Troubleshooting

### Enable Debug Logging

```bash
OTEL_LOG_LEVEL=debug node --require @opentelemetry/auto-instrumentations-node/register app.js
```

### Verify Telemetry is Sent

Check Alloy logs:

```bash
docker compose logs -f alloy
```

### Check Grafana Datasources

1. Go to **Configuration** → **Data sources** in Grafana
2. Test each datasource (Tempo, Loki, Prometheus)

## Advanced Configuration

### Custom Span Attributes

You can still add custom attributes in code while using auto-instrumentation:

```javascript
const { trace } = require('@opentelemetry/api');

app.get('/custom', (req, res) => {
  const span = trace.getActiveSpan();
  if (span) {
    span.setAttribute('user.id', '12345');
    span.setAttribute('custom.attribute', 'value');
  }
  res.json({ message: 'Custom attributes added' });
});
```

### Manual Instrumentation Alongside Auto-Instrumentation

```javascript
const { trace } = require('@opentelemetry/api');

const tracer = trace.getTracer('my-custom-tracer');

app.get('/manual', async (req, res) => {
  const span = tracer.startSpan('custom-operation');

  try {
    // Your operation
    await someOperation();
    span.setStatus({ code: 1 }); // OK
  } catch (error) {
    span.setStatus({ code: 2, message: error.message }); // ERROR
    span.recordException(error);
    throw error;
  } finally {
    span.end();
  }

  res.json({ message: 'Done' });
});
```

## Summary

✅ **Zero code changes required** - just environment variables
✅ **Automatic instrumentation** of popular libraries
✅ **Full observability** - traces, metrics, and logs
✅ **Easy to enable/disable** - just change ENV vars
✅ **Production-ready** with proper sampling and configuration

For more information, see:
- [OpenTelemetry Node.js Documentation](https://opentelemetry.io/docs/languages/js/)
- [Auto-Instrumentation Package](https://www.npmjs.com/package/@opentelemetry/auto-instrumentations-node)
