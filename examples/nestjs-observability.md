# NestJS Complete Observability Setup

This guide shows how to instrument a NestJS application with OpenTelemetry for traces, metrics, logs, and Pyroscope for continuous profiling.

## Quick Start

### 1. Install Dependencies

```bash
npm install --save @opentelemetry/api
npm install --save @opentelemetry/auto-instrumentations-node
npm install --save @pyroscope/nodejs
```

### 2. Configure Environment Variables

Copy the comprehensive NestJS configuration:

```bash
cp .env.nestjs.example .env
```

Edit `.env` and configure for your environment:

```bash
# Minimal required settings
OTEL_SERVICE_NAME=my-nestjs-app
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
PYROSCOPE_SERVER_ADDRESS=http://alloy:4100
PYROSCOPE_APPLICATION_NAME=my-nestjs-app
```

### 3. Add Profiling Initialization

Create `src/profiling.ts`:

```typescript
import Pyroscope from '@pyroscope/nodejs';

export function initProfiling() {
  if (process.env.PYROSCOPE_SERVER_ADDRESS) {
    Pyroscope.init({
      serverAddress: process.env.PYROSCOPE_SERVER_ADDRESS,
      appName: process.env.PYROSCOPE_APPLICATION_NAME || 'nestjs-app',
      tags: parseTags(process.env.PYROSCOPE_TAGS),
      sampleRate: parseInt(process.env.PYROSCOPE_SAMPLE_RATE || '100'),
    });

    Pyroscope.start();
    console.log('✅ Pyroscope profiling initialized');
  }
}

function parseTags(tagsStr?: string): Record<string, string> {
  if (!tagsStr) return {};

  return tagsStr.split(',').reduce((acc, tag) => {
    const [key, value] = tag.split('=');
    if (key && value) acc[key.trim()] = value.trim();
    return acc;
  }, {} as Record<string, string>);
}
```

### 4. Update main.ts

```typescript
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { initProfiling } from './profiling';

async function bootstrap() {
  // Initialize profiling first
  initProfiling();

  const app = await NestFactory.create(AppModule);

  // Your app configuration
  await app.listen(process.env.PORT || 3000);

  console.log(`🚀 Application is running on: ${await app.getUrl()}`);
  console.log(`📊 OpenTelemetry: ${process.env.OTEL_SERVICE_NAME || 'not configured'}`);
}

bootstrap();
```

### 5. Update package.json Scripts

```json
{
  "scripts": {
    "start": "node --require @opentelemetry/auto-instrumentations-node/register dist/main",
    "start:dev": "NODE_ENV=development nest start --watch",
    "start:prod": "node --require @opentelemetry/auto-instrumentations-node/register --max-old-space-size=2048 dist/main"
  }
}
```

### 6. Docker Compose Example

```yaml
version: '3.8'

services:
  nestjs-app:
    build: .
    ports:
      - "3000:3000"
    environment:
      # Application
      - NODE_ENV=production
      - PORT=3000

      # OpenTelemetry
      - OTEL_SERVICE_NAME=my-nestjs-app
      - OTEL_SERVICE_VERSION=1.0.0
      - OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.namespace=backend
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4317
      - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
      - OTEL_TRACES_EXPORTER=otlp
      - OTEL_METRICS_EXPORTER=otlp
      - OTEL_LOGS_EXPORTER=otlp
      - OTEL_TRACES_SAMPLER=parentbased_traceidratio
      - OTEL_TRACES_SAMPLER_ARG=0.1
      - OTEL_BSP_MAX_QUEUE_SIZE=2048
      - OTEL_BSP_MAX_EXPORT_BATCH_SIZE=512
      - OTEL_PROPAGATORS=tracecontext,baggage
      - OTEL_LOG_LEVEL=info

      # Profiling
      - PYROSCOPE_SERVER_ADDRESS=http://alloy:4100
      - PYROSCOPE_APPLICATION_NAME=my-nestjs-app
      - PYROSCOPE_TAGS=environment=production,version=1.0.0

      # Database
      - DATABASE_URL=postgresql://user:pass@postgres:5432/db
      - REDIS_HOST=redis
      - REDIS_PORT=6379

    networks:
      - observability

    depends_on:
      - postgres
      - redis
      - alloy

  postgres:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=db
    networks:
      - observability

  redis:
    image: redis:7-alpine
    networks:
      - observability

networks:
  observability:
    external: true
    name: instrumenting_observability
```

### 7. Dockerfile

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source
COPY . .

# Build application
RUN npm run build

# Production stage
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy built application
COPY --from=builder /app/dist ./dist

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

# Start with OpenTelemetry auto-instrumentation
CMD ["node", "--require", "@opentelemetry/auto-instrumentations-node/register", "--max-old-space-size=2048", "dist/main"]
```

## What Gets Automatically Instrumented

OpenTelemetry auto-instrumentation automatically captures:

### HTTP Layer
- ✅ All HTTP requests/responses
- ✅ Request method, URL, status code
- ✅ Request/response headers
- ✅ Query parameters

### NestJS Framework
- ✅ Controllers and routes
- ✅ Guards execution
- ✅ Interceptors
- ✅ Pipes and validation
- ✅ Exception filters
- ✅ Middleware

### Database
- ✅ PostgreSQL queries (via `pg` driver)
- ✅ MySQL queries (via `mysql2` driver)
- ✅ MongoDB operations (via `mongodb` driver)
- ✅ TypeORM operations
- ✅ Prisma queries
- ✅ Sequelize operations

### Caching & Queuing
- ✅ Redis commands
- ✅ Bull/BullMQ jobs
- ✅ ioredis operations

### External Services
- ✅ HTTP client requests (`axios`, `node-fetch`, `got`)
- ✅ gRPC calls
- ✅ AWS SDK operations
- ✅ GraphQL operations (if using `@nestjs/graphql`)

### Messaging
- ✅ Kafka producers/consumers
- ✅ RabbitMQ/AMQP
- ✅ MQTT
- ✅ NestJS Microservices

## Custom Instrumentation

### Adding Custom Spans

```typescript
import { Injectable } from '@nestjs/common';
import { trace } from '@opentelemetry/api';

@Injectable()
export class UserService {
  private readonly tracer = trace.getTracer('user-service');

  async findUser(id: string) {
    // Create a custom span
    return await this.tracer.startActiveSpan('findUser', async (span) => {
      try {
        // Add attributes
        span.setAttribute('user.id', id);
        span.setAttribute('operation', 'database.query');

        // Your logic
        const user = await this.userRepository.findOne(id);

        // Add result attributes
        span.setAttribute('user.found', !!user);

        return user;
      } catch (error) {
        // Record exceptions
        span.recordException(error);
        span.setStatus({ code: 2, message: error.message });
        throw error;
      } finally {
        span.end();
      }
    });
  }
}
```

### Adding Custom Attributes to Active Span

```typescript
import { Injectable } from '@nestjs/common';
import { trace } from '@opentelemetry/api';

@Injectable()
export class OrderService {
  async createOrder(orderData: any) {
    const span = trace.getActiveSpan();

    if (span) {
      span.setAttribute('order.amount', orderData.amount);
      span.setAttribute('order.items', orderData.items.length);
      span.setAttribute('customer.id', orderData.customerId);
    }

    // Your logic
    return await this.orderRepository.create(orderData);
  }
}
```

### Creating a Tracing Interceptor

```typescript
import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { trace } from '@opentelemetry/api';

@Injectable()
export class TracingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const span = trace.getActiveSpan();
    const request = context.switchToHttp().getRequest();

    if (span) {
      // Add custom attributes
      span.setAttribute('user.id', request.user?.id);
      span.setAttribute('tenant.id', request.tenant?.id);
      span.setAttribute('request.ip', request.ip);
    }

    return next.handle().pipe(
      tap({
        next: (data) => {
          if (span) {
            span.setAttribute('response.success', true);
            span.setAttribute('response.items', data?.length || 0);
          }
        },
        error: (error) => {
          if (span) {
            span.recordException(error);
            span.setAttribute('response.success', false);
          }
        },
      }),
    );
  }
}
```

## Environment Variable Guide

### Critical Settings

```bash
# Must configure
OTEL_SERVICE_NAME=my-nestjs-app              # Unique service identifier
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy:4317  # Alloy endpoint
OTEL_EXPORTER_OTLP_PROTOCOL=grpc             # Use gRPC for best performance

# Enable signals
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
```

### Production Settings

```bash
# Sampling: 10% of traces
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1

# Batch processing for efficiency
OTEL_BSP_MAX_QUEUE_SIZE=2048
OTEL_BSP_MAX_EXPORT_BATCH_SIZE=512
OTEL_BSP_SCHEDULE_DELAY=5000

# Resource attributes for filtering
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production,service.version=1.0.0,cloud.region=us-east-1
```

### Development Settings

```bash
# Sample everything in development
OTEL_TRACES_SAMPLER=always_on
OTEL_TRACES_SAMPLER_ARG=1.0

# Debug logging
OTEL_LOG_LEVEL=debug

# Local Alloy
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4320
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

### Performance Tuning

```bash
# For high-traffic applications
OTEL_TRACES_SAMPLER_ARG=0.05              # Sample 5%
OTEL_BSP_MAX_QUEUE_SIZE=4096              # Larger queue
OTEL_BSP_MAX_EXPORT_BATCH_SIZE=1024       # Larger batches
OTEL_METRIC_EXPORT_INTERVAL=120000        # Export metrics every 2 minutes

# Disable instrumentations causing overhead
OTEL_NODE_DISABLED_INSTRUMENTATIONS=fs,dns
```

## Viewing Data in Grafana

### 1. Start Everything

```bash
# Start observability stack
docker compose up -d

# Start your NestJS app
npm run start:prod
```

### 2. View Traces

1. Open Grafana: http://localhost:3000
2. Go to **Explore** → Select **Tempo**
3. Search for service: `my-nestjs-app`
4. Click on traces to see:
   - Request flow
   - Database queries
   - External API calls
   - Performance bottlenecks

### 3. View Logs

1. In **Explore** → Select **Loki**
2. Query: `{service_name="my-nestjs-app"}`
3. Click on log entry → Click **"Tempo"** button to see related trace

### 4. View Metrics

1. In **Explore** → Select **Prometheus**
2. Query examples:
   ```promql
   # Request rate
   rate(http_server_duration_ms_count{service_name="my-nestjs-app"}[5m])

   # Error rate
   rate(http_server_duration_ms_count{service_name="my-nestjs-app",http_status_code=~"5.."}[5m])

   # P95 latency
   histogram_quantile(0.95, rate(http_server_duration_ms_bucket{service_name="my-nestjs-app"}[5m]))
   ```

### 5. View Profiles

1. In **Explore** → Select **Pyroscope**
2. Select service: `my-nestjs-app`
3. View flamegraphs for:
   - CPU usage
   - Memory allocation
   - Event loop lag

### 6. Correlate Everything

1. View a trace in Tempo
2. Click **"Logs for this span"** → See related logs
3. Click **"View Profile"** → See CPU/memory during that request
4. See related metrics in the metrics panel

## Best Practices for NestJS

### 1. Health Check Endpoints

Exclude health checks from traces (already configured in Alloy):

```typescript
@Controller('health')
export class HealthController {
  @Get()
  check() {
    return { status: 'ok' };
  }
}
```

### 2. Database Queries

Avoid N+1 queries - they're clearly visible in traces:

```typescript
// ❌ Bad - generates N+1 queries visible in traces
async getUsers() {
  const users = await this.userRepository.find();
  for (const user of users) {
    user.orders = await this.orderRepository.findByUser(user.id);
  }
  return users;
}

// ✅ Good - single query visible in traces
async getUsers() {
  return await this.userRepository.find({
    relations: ['orders'],
  });
}
```

### 3. Async Operations

Long-running operations should be traced:

```typescript
import { trace } from '@opentelemetry/api';

async function processLargeFile(file: File) {
  const tracer = trace.getTracer('file-processor');

  return await tracer.startActiveSpan('processLargeFile', async (span) => {
    span.setAttribute('file.size', file.size);
    span.setAttribute('file.type', file.type);

    try {
      // Processing logic
      const result = await heavyProcessing(file);
      span.setAttribute('chunks.processed', result.chunks);
      return result;
    } finally {
      span.end();
    }
  });
}
```

### 4. Error Handling

Always record exceptions in spans:

```typescript
try {
  await riskyOperation();
} catch (error) {
  const span = trace.getActiveSpan();
  if (span) {
    span.recordException(error);
    span.setStatus({ code: 2, message: error.message });
  }
  throw error;
}
```

### 5. Sampling Strategy

For production with high traffic:

```bash
# Start with 10% sampling
OTEL_TRACES_SAMPLER_ARG=0.1

# Monitor in Grafana, adjust if needed:
# - More traffic? Lower to 5% (0.05)
# - Missing important traces? Increase to 20% (0.2)
# - Debugging issue? Temporarily set to 100% (1.0)
```

## Troubleshooting

### No traces appearing

```bash
# Check OpenTelemetry is loaded
# Should see: "OpenTelemetry automatic instrumentation started"
npm run start:prod 2>&1 | grep -i opentelemetry

# Check environment variables
node -e "console.log(process.env.OTEL_SERVICE_NAME)"

# Check Alloy connectivity
curl http://alloy:4317  # Should connect
```

### High memory usage

```bash
# Increase Node.js heap size
NODE_OPTIONS="--require @opentelemetry/auto-instrumentations-node/register --max-old-space-size=4096"

# Or reduce batch sizes
OTEL_BSP_MAX_QUEUE_SIZE=1024
OTEL_BSP_MAX_EXPORT_BATCH_SIZE=256
```

### Missing database queries

```bash
# Ensure database driver is installed
npm list pg  # For PostgreSQL
npm list mysql2  # For MySQL

# Check driver is not disabled
# Make sure this is NOT set:
# OTEL_NODE_DISABLED_INSTRUMENTATIONS=pg
```

### Profiling not working

```bash
# Check Pyroscope initialization
# Should see: "✅ Pyroscope profiling initialized"

# Check connectivity
curl http://alloy:4100

# Enable debug logging
OTEL_LOG_LEVEL=debug
```

## Complete Example Repository Structure

```
nestjs-app/
├── src/
│   ├── main.ts                 # Bootstrap with profiling
│   ├── profiling.ts            # Profiling initialization
│   ├── app.module.ts
│   ├── users/
│   │   ├── users.controller.ts
│   │   ├── users.service.ts    # Custom spans
│   │   └── users.module.ts
│   └── common/
│       └── interceptors/
│           └── tracing.interceptor.ts
├── .env                        # Environment config
├── .env.nestjs.example         # Template with all settings
├── docker-compose.yml          # With observability
├── Dockerfile                  # With OTel
└── package.json                # With dependencies
```

## Summary

✅ Zero-code instrumentation for most operations
✅ Comprehensive traces, metrics, and logs
✅ Continuous profiling with Pyroscope
✅ Full correlation in Grafana
✅ Production-ready configuration
✅ Easy Docker/Kubernetes deployment

For more information:
- [OpenTelemetry Node.js Docs](https://opentelemetry.io/docs/languages/js/)
- [NestJS Documentation](https://docs.nestjs.com/)
- [Grafana Observability](https://grafana.com/docs/)
