# Observability Stack with Grafana, Tempo, Loki, and Alloy

A Docker Compose setup for full-stack observability with distributed tracing, log aggregation, and metrics collection.

## Components

- **Grafana**: Visualization and dashboards (port 3000)
- **Tempo**: Distributed tracing backend (ports 3200, 4317, 4318)
- **Loki**: Log aggregation system (port 3100)
- **Alloy**: OpenTelemetry collector for telemetry data (ports 12345, 4319, 4320)

## Quick Start

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Stop all services
docker compose down

# Stop and remove volumes
docker compose down -v
```

## Access

- **Grafana UI**: http://localhost:3000
  - No login required (anonymous admin access enabled by default)
- **Alloy UI**: http://localhost:12345
- **Tempo**: http://localhost:3200
- **Loki**: http://localhost:3100

## Sending Telemetry Data

### OTLP (OpenTelemetry Protocol)

Send traces, logs, and metrics to Alloy using OTLP:

**gRPC endpoint**: `http://localhost:4319`
**HTTP endpoint**: `http://localhost:4320`

### Example: Send traces with OpenTelemetry SDK

```javascript
// Node.js example
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const provider = new NodeTracerProvider();
provider.addSpanProcessor(
  new SimpleSpanProcessor(
    new OTLPTraceExporter({
      url: 'http://localhost:4320/v1/traces',
    })
  )
);
provider.register();
```

### Example: Send logs to Loki directly

```bash
curl -X POST http://localhost:3100/loki/api/v1/push \
  -H "Content-Type: application/json" \
  -d '{
    "streams": [
      {
        "stream": {
          "job": "test",
          "level": "info"
        },
        "values": [
          ["'$(date +%s)000000000'", "test log message"]
        ]
      }
    ]
  }'
```

## Configuration

All configurations are stored in the `config/` directory and can be easily customized.

### Directory Structure

```
.
├── docker-compose.yml
├── config/
│   ├── grafana/
│   │   └── datasources.yml    # Grafana datasource configuration
│   ├── tempo/
│   │   └── tempo.yml           # Tempo configuration
│   ├── loki/
│   │   └── loki.yml            # Loki configuration
│   └── alloy/
│       └── config.alloy        # Alloy configuration (River format)
└── README.md
```

### Customizing Tempo (config/tempo/tempo.yml)

Key settings to customize:

```yaml
compactor:
  compaction:
    block_retention: 24h        # How long to keep traces (default: 24 hours)

query_frontend:
  search:
    max_result_limit: 100       # Maximum search results
```

### Customizing Loki (config/loki/loki.yml)

Key settings to customize:

```yaml
limits_config:
  retention_period: 168h        # Log retention (default: 7 days)
  ingestion_rate_mb: 16         # Ingestion rate limit
  max_query_series: 1000        # Max series in query
```

### Customizing Alloy (config/alloy/config.alloy)

Key settings to customize:

```hcl
// Batch processing
otelcol.processor.batch "default" {
  timeout          = "5s"       # Batch timeout
  send_batch_size  = 100        # Batch size
  // ...
}
```

### Customizing Grafana Datasources (config/grafana/datasources.yml)

Modify datasource connections and correlations between traces, logs, and metrics.

## Environment Variables

You can customize the Docker Compose setup using environment variables in `docker-compose.yml`:

### Grafana

```yaml
environment:
  - GF_AUTH_ANONYMOUS_ENABLED=true    # Enable anonymous access
  - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin  # Role for anonymous users
  - GF_AUTH_DISABLE_LOGIN_FORM=true   # Hide login form
```

For production, disable anonymous access:

```yaml
environment:
  - GF_AUTH_ANONYMOUS_ENABLED=false
  - GF_SECURITY_ADMIN_PASSWORD=your_secure_password
```

## Persistence

Data is persisted using Docker volumes:

- `grafana-data`: Grafana dashboards and settings
- `tempo-data`: Tempo traces
- `loki-data`: Loki logs
- `alloy-data`: Alloy state

To reset all data:

```bash
docker compose down -v
```

## Troubleshooting

### Check service health

```bash
# Check if all containers are running
docker compose ps

# Check specific service logs
docker compose logs grafana
docker compose logs tempo
docker compose logs loki
docker compose logs alloy
```

### Test Tempo

```bash
curl http://localhost:3200/ready
```

### Test Loki

```bash
curl http://localhost:3100/ready
```

### Test Alloy

```bash
curl http://localhost:12345/
```

## Advanced Configuration

### Adding Authentication

Edit `docker-compose.yml` and update Grafana environment variables:

```yaml
environment:
  - GF_AUTH_ANONYMOUS_ENABLED=false
  - GF_SECURITY_ADMIN_USER=admin
  - GF_SECURITY_ADMIN_PASSWORD=your_password
```

### Scaling

For production use, consider:

1. Using external storage (S3, GCS) for Tempo and Loki
2. Adding Prometheus for metrics
3. Enabling authentication and TLS
4. Using Grafana Mimir for long-term metrics storage
5. Implementing retention policies based on your needs

### Resource Limits

Add resource limits in `docker-compose.yml`:

```yaml
services:
  tempo:
    # ...
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

## Integration Examples

### Python (OpenTelemetry)

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

provider = TracerProvider()
processor = BatchSpanProcessor(
    OTLPSpanExporter(endpoint="http://localhost:4320/v1/traces")
)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("example-span"):
    print("Hello, World!")
```

### Go (OpenTelemetry)

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

exporter, _ := otlptracehttp.New(
    context.Background(),
    otlptracehttp.WithEndpoint("localhost:4320"),
    otlptracehttp.WithInsecure(),
)

tp := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exporter),
)
otel.SetTracerProvider(tp)
```

## License

This configuration is provided as-is for educational and development purposes.
