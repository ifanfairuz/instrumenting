# Docker Profiling with Pyroscope via Alloy

This guide shows how to collect profiling data from Docker containers and send it to Pyroscope via Alloy.

## Overview

Alloy provides multiple ways to collect profiling data:

1. **eBPF Profiling** (Zero-instrumentation): Alloy automatically discovers and profiles all Docker containers using eBPF - no code changes needed!
2. **Push-based Profiling**: Applications push profiling data to Alloy on port **4100**
3. **Pull-based Profiling**: Alloy scrapes pprof endpoints from Go applications

## Method 1: eBPF Profiling (Automatic - Recommended)

**No code changes required!** Alloy is configured with eBPF profiling that automatically:
- Discovers all running Docker containers
- Profiles CPU usage for all processes
- Works with any language (Go, Node.js, Python, Java, C++, Rust, etc.)
- Zero overhead (<1% CPU)
- No application instrumentation needed

### How it Works

Alloy uses eBPF to sample stack traces directly from the kernel, providing continuous profiling for all containers without any application instrumentation.

### Setup

The stack is already configured! Just start it:

```bash
docker compose up -d
```

### Viewing eBPF Profiles

1. Start your application containers (they'll be automatically discovered)
2. Wait 1-2 minutes for profiles to accumulate
3. Open Grafana: http://localhost:3000
4. Navigate to **Explore** → Select **Pyroscope** datasource
5. Look for your container names in the service list

### Requirements

The Alloy container runs with:
- `privileged: true` - Required for eBPF
- `pid: host` - Access to host process information
- Docker socket access - For container discovery
- `/sys/kernel/debug` - For BPF debugging
- `/sys/fs/cgroup` - For cgroup information

**Note**: eBPF profiling provides CPU profiling. For memory profiling, use push-based methods below.

### Filtering

To profile only specific containers, edit `config/alloy/config.alloy`:

```hcl
pyroscope.ebpf "instance" {
  forward_to = [pyroscope.write.default.receiver]
  targets = discovery.docker.local_containers.targets

  // Only profile containers with specific labels
  targets_only_with_label = ["profiling=enabled"]
}
```

Then add labels to your containers:

```yaml
services:
  myapp:
    image: myapp:latest
    labels:
      - "profiling=enabled"
```

## Method 2: Push-based Profiling

For detailed memory profiling, garbage collection analysis, or custom profiling, use push-based profiling.

### Profiling Endpoint

- **Push URL**: `http://localhost:4100` (or `http://alloy:4100` from within Docker network)

### Node.js Profiling

Install the Pyroscope Node.js package:

```bash
npm install @pyroscope/nodejs
```

Add at the beginning of your app entry point:

```javascript
const Pyroscope = require('@pyroscope/nodejs');

Pyroscope.init({
  serverAddress: 'http://alloy:4100',  // Inside Docker network
  appName: 'nodejs-app',
  tags: {
    environment: 'production',
    version: '1.0.0',
  },
  sampleRate: 100,  // Sample every 100ms
});

Pyroscope.start();

// Your application code follows...
```

**Docker Compose Example**:

```yaml
services:
  nodejs-app:
    build: .
    environment:
      - PYROSCOPE_SERVER_ADDRESS=http://alloy:4100
      - PYROSCOPE_APPLICATION_NAME=nodejs-app
    networks:
      - observability
    depends_on:
      - alloy

networks:
  observability:
    external: true
    name: instrumenting_observability
```

### Python Profiling

Install the Pyroscope Python package:

```bash
pip install pyroscope-io
```

Configure in your application:

```python
import pyroscope

pyroscope.configure(
    application_name="python-app",
    server_address="http://alloy:4100",
    tags={
        "environment": "production",
        "version": "1.0.0",
    },
)

# Your application code follows...
```

**Docker Compose Example**:

```yaml
services:
  python-app:
    build: .
    environment:
      - PYROSCOPE_SERVER_ADDRESS=http://alloy:4100
      - PYROSCOPE_APPLICATION_NAME=python-app
    networks:
      - observability
    depends_on:
      - alloy

networks:
  observability:
    external: true
    name: instrumenting_observability
```

### Go Profiling

```go
package main

import (
    "github.com/grafana/pyroscope-go"
)

func main() {
    pyroscope.Start(pyroscope.Config{
        ApplicationName: "go-app",
        ServerAddress:   "http://alloy:4100",
        Tags: map[string]string{
            "environment": "production",
        },
        ProfileTypes: []pyroscope.ProfileType{
            pyroscope.ProfileCPU,
            pyroscope.ProfileAllocObjects,
            pyroscope.ProfileAllocSpace,
            pyroscope.ProfileInuseObjects,
            pyroscope.ProfileInuseSpace,
        },
    })

    // Your application code...
}
```

### Java Profiling

Download and use the Pyroscope Java agent:

```dockerfile
FROM openjdk:17-slim

RUN curl -L -o /app/pyroscope.jar \
    https://github.com/grafana/pyroscope-java/releases/latest/download/pyroscope.jar

COPY target/app.jar /app/app.jar

ENTRYPOINT ["java", \
    "-javaagent:/app/pyroscope.jar", \
    "-jar", "/app/app.jar"]
```

**Docker Compose Example**:

```yaml
services:
  java-app:
    build: .
    environment:
      - PYROSCOPE_SERVER_ADDRESS=http://alloy:4100
      - PYROSCOPE_APPLICATION_NAME=java-app
      - PYROSCOPE_FORMAT=jfr
    networks:
      - observability
```

## Method 3: Pull-based (Go pprof)

For Go applications exposing standard pprof endpoints, Alloy can scrape profiles.

### 1. Expose pprof in your Go application

```go
package main

import (
    "net/http"
    _ "net/http/pprof"
)

func main() {
    // Expose pprof on port 6060
    go func() {
        http.ListenAndServe(":6060", nil)
    }()

    // Your application code...
}
```

### 2. Configure Alloy to scrape

Edit `config/alloy/config.alloy` and uncomment/add:

```hcl
pyroscope.scrape "apps" {
  targets = [
    {
      "__address__" = "go-app:6060",
      "service_name" = "go-app",
    },
  ]
  forward_to = [pyroscope.write.default.receiver]

  profiling_config {
    profile.process_cpu {
      enabled = true
      path = "/debug/pprof/profile"
      delta = true
    }
    profile.memory {
      enabled = true
      path = "/debug/pprof/heap"
    }
  }
}
```

### 3. Docker Compose Example

```yaml
services:
  go-app:
    build: .
    expose:
      - "6060"  # Expose pprof internally
    networks:
      - observability

networks:
  observability:
    external: true
    name: instrumenting_observability
```

## Viewing Profiles in Grafana

1. Open Grafana: http://localhost:3000
2. Login with `admin/admin`
3. Navigate to **Explore**
4. Select **Pyroscope** datasource
5. Select your application and profile type
6. View flamegraphs and time series

### Correlating Profiles with Traces

When sending both traces and profiles:

1. View a trace in Tempo
2. Click on a span
3. Click **"View Profile"** to see the CPU/memory profile during that span
4. Identify performance bottlenecks in specific operations

## Comparison of Methods

| Method | Languages | Setup | Overhead | Profile Types |
|--------|-----------|-------|----------|---------------|
| **eBPF** | All | None | <1% | CPU only |
| **Push** | Most | Easy | 1-5% | CPU, Memory, GC |
| **Pull (pprof)** | Go mainly | Easy | 1-3% | CPU, Memory, Goroutines |

**Recommendation**: Start with eBPF for zero-config CPU profiling. Add push-based profiling when you need memory/GC analysis.

## Best Practices

1. **Start with eBPF**: Get immediate CPU profiling for all containers
2. **Add push-based for details**: When you need memory profiling or GC analysis
3. **Use meaningful names**: Application names should match your service names in traces
4. **Add tags**: Include `environment`, `version`, `region` for filtering
5. **Sample rate**: Use 100Hz (10ms) for production to minimize overhead

## Testing

### Start the stack

```bash
docker compose up -d
```

### Verify eBPF profiling is working

```bash
# Check Alloy logs
docker compose logs alloy | grep ebpf

# Should see: "component started" for pyroscope.ebpf
```

### Generate load

```bash
# For any app
while true; do
  curl http://localhost:3000/api/endpoint
  sleep 0.1
done
```

### View profiles

After 1-2 minutes, profiles will appear in Grafana → Explore → Pyroscope.

## Troubleshooting

### eBPF profiling not working

```bash
# Check if eBPF is enabled in kernel
docker compose exec alloy sh -c "ls /sys/kernel/debug/tracing"

# Check container is privileged
docker inspect instrumenting-alloy-1 | grep Privileged

# Should show: "Privileged": true
```

### No profiles appearing

```bash
# Check Alloy is discovering containers
docker compose logs alloy | grep discovery

# Check Pyroscope is receiving data
docker compose logs pyroscope | grep ingest
```

### Permission denied errors

Ensure Alloy has:
- `privileged: true`
- `pid: host`
- `/var/run/docker.sock` mounted

### High overhead

- Reduce sample rate for push-based profiling
- eBPF profiling has minimal overhead by design

## Architecture

```
Docker Containers
    |
    | 1. eBPF (automatic CPU profiling)
    | 2. Push profiles (port 4100)
    | 3. Scrape pprof (Go apps)
    ↓
Alloy
    |
    | Forward profiles
    ↓
Pyroscope (Storage)
    |
    | Query profiles
    ↓
Grafana (Visualization)
```

## Next Steps

- Profile production workloads with zero overhead using eBPF
- Add push-based profiling for memory analysis
- Correlate profiles with traces to find bottlenecks
- Set up alerts for CPU/memory spikes
- Compare profiles across versions to catch regressions
