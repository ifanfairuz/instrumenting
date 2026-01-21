# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**UPDATE THIS IF MAKE BREAKING CHANGES**

## Project Overview

This is a Docker-based observability stack implementing the LGTM+ architecture:

- **L**oki: Log aggregation
- **G**rafana: Visualization and dashboards
- **T**empo: Distributed tracing
- **M**imir/Prometheus: Metrics storage
- **P**yroscope: Continuous profiling

**Alloy** acts as the OpenTelemetry collector that receives telemetry data (traces, logs, metrics, profiling) via OTLP and routes it to the appropriate backend services.

## Common Commands

### Stack Management

```bash
# Start all services
make up
# or: docker compose up -d

# Stop all services
make down
# or: docker compose down

# Stop and remove all data volumes (full reset)
make clean
# or: docker compose down -v

# Check service health
make status

# View logs
make logs
# or: docker compose logs -f
# or: docker compose logs -f <service-name>  # For specific service
```

### Testing

**Python test application** (generates order processing traces):

```bash
make test-app
# or manually:
python3 -m venv examples/venv
examples/venv/bin/pip install -r examples/requirements.txt
examples/venv/bin/python examples/test-app.py
```

**Node.js example** (auto-instrumented Express app):

```bash
cd examples/nodejs-example
npm install
npm start

# Generate test traffic
./generate-traffic.sh 60  # Runs for 60 seconds
```

### Service Access

- Grafana UI: http://localhost:3000 (admin/admin)
- Alloy UI: http://localhost:12345
- Tempo API: http://localhost:3200
- Loki API: http://localhost:3100

### OTLP Endpoints (for sending telemetry)

- gRPC: `localhost:4319` (mapped from Alloy's internal 4317)
- HTTP: `localhost:4320` (mapped from Alloy's internal 4318)

## Architecture

### Data Flow

1. **Applications** → Send telemetry via OTLP → **Alloy** (ports 4319/4320)
2. **Alloy** → Routes telemetry to backends:
   - Traces → **Tempo** (via gRPC on internal network)
   - Logs → **Loki** (via HTTP push API)
   - Metrics → **Prometheus** (via remote write API)
   - Profiles → **Pyroscope** (via HTTP)
3. **Grafana** → Queries all backends and correlates data

### Service Dependencies

- **Alloy** depends on: Tempo, Loki, Prometheus, Pyroscope
- All services communicate over the `observability` Docker network
- Internal service discovery uses Docker service names (e.g., `tempo:4317`)

### Configuration Files

All configurations are in `config/`:

```
config/
├── alloy/config.alloy          # Alloy pipeline (River format)
├── grafana/datasources.yml     # Datasource definitions & correlations
├── loki/loki.yml               # Log retention, ingestion limits
├── prometheus/prometheus.yml   # Scrape configs, storage
├── pyroscope/config.yml        # Profiling storage
└── tempo/tempo.yml             # Trace retention, query limits
```

**Important**: Alloy uses the River configuration language (`.alloy` files), not YAML.

### Grafana Datasource Correlations

Grafana is pre-configured with correlations between all data sources in `config/grafana/datasources.yml`:

- **Tempo → Loki**: Click "Logs for this span" to see logs for a trace
- **Tempo → Prometheus**: View metrics correlated with traces
- **Tempo → Pyroscope**: Jump from traces to CPU/memory profiles
- **Loki → Tempo**: Extract trace IDs from logs to view related traces
- **Prometheus → Tempo**: Navigate from metrics to exemplar traces

## Key Configuration Settings

### Alloy Pipeline (config/alloy/config.alloy)

The Alloy configuration defines the telemetry processing pipeline:

```
OTLP Receiver (4317/4318)
  → Batch Processor (batches for efficiency)
    → Exporters:
       - Traces → otelcol.exporter.otlp "tempo"
       - Logs → otelcol.exporter.loki "default" → loki.write "local"
       - Metrics → otelcol.exporter.prometheus "default" → prometheus.remote_write "local"
```

Key settings to adjust:

- `timeout`: Batch timeout (default: 5s)
- `send_batch_size`: Batch size (default: 100)

### Tempo (config/tempo/tempo.yml)

Key retention setting: `compactor.compaction.block_retention: 24h` (default: 24 hours)

### Loki (config/loki/loki.yml)

Key retention setting: `limits_config.retention_period: 168h` (default: 7 days)

### Prometheus (config/prometheus/prometheus.yml)

Retention configured in `docker-compose.yml`: `--storage.tsdb.retention.time=15d`

## Instrumentation Patterns

### Node.js Auto-Instrumentation

The repository provides a zero-code-change approach using environment variables:

```bash
export OTEL_SERVICE_NAME="my-app"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4320"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_TRACES_EXPORTER="otlp"
export OTEL_METRICS_EXPORTER="otlp"
export OTEL_LOGS_EXPORTER="otlp"

node --require @opentelemetry/auto-instrumentations-node/register app.js
```

See `examples/nodejs-auto-instrument.md` for comprehensive documentation.

### Python Manual Instrumentation

See `examples/test-app.py` for a complete example using:

- `opentelemetry-api`
- `opentelemetry-sdk`
- `opentelemetry-exporter-otlp`

Endpoint: `http://localhost:4320/v1/traces`

## Development Notes

### Port Configuration

Most services have their ports commented out in `docker-compose.yml` to reduce exposed ports. Only Alloy's OTLP endpoints (4319, 4320) and Loki (3100) are exposed by default. To expose additional ports (e.g., for direct access to Grafana, Tempo), uncomment the relevant port mappings in `docker-compose.yml`.

### Authentication

Default configuration has Grafana authentication disabled for development:

```yaml
GF_AUTH_ANONYMOUS_ENABLED=false  # Currently set to false
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
```

For production, ensure anonymous access is disabled and use strong passwords.

### Network

All services run in the `observability` Docker network. To connect external applications:

```bash
docker run --network instrumenting_observability ...
```

### Data Persistence

Data is persisted in Docker volumes:

- `grafana-data`: Dashboards and settings
- `tempo-data`: Trace data
- `loki-data`: Log data
- `prometheus-data`: Metric data
- `pyroscope-data`: Profile data
- `alloy-data`: Alloy state

To completely reset: `make clean` or `docker compose down -v`

## Troubleshooting

### Check Service Health

```bash
curl http://localhost:3200/ready  # Tempo
curl http://localhost:3100/ready  # Loki
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:12345/  # Alloy
```

### View Service Logs

```bash
docker compose logs -f alloy    # Most useful for debugging telemetry flow
docker compose logs -f tempo
docker compose logs -f loki
docker compose logs -f grafana
```

### Verify Telemetry Flow

1. Check Alloy is receiving data: `docker compose logs -f alloy`
2. Check Grafana datasources: Configuration → Data sources → Test each datasource
3. Query data in Grafana Explore:
   - Select Tempo datasource → Search for traces
   - Select Loki datasource → Query logs with LogQL
   - Select Prometheus datasource → Query metrics with PromQL

### Common Issues

- **No traces in Tempo**: Check Alloy logs, verify OTLP endpoint is correct (4320 for HTTP, 4319 for gRPC)
- **Grafana can't connect to datasources**: Ensure all services are running (`docker compose ps`)
- **Memory issues**: Adjust retention periods in Tempo and Loki configs, or add Docker resource limits in `docker-compose.yml`
