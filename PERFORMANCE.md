# Consul Connect Performance Comparison Report

This report compares the performance of the test application when accessed directly and when accessed through the Consul Connect/Envoy sidecar architecture.

The comparison focuses on request latency, CPU usage, and memory usage to evaluate the performance overhead introduced by the service-mesh layer.

## 1. Objective

The objective of this test is to measure and compare the performance of the application in two configurations:

1. Direct application access without the Consul Connect/Envoy proxy.
2. Application access through the Consul Connect/Envoy TLS path.

The measurements are used to identify the latency and resource overhead associated with the Consul Connect service-mesh architecture.

## 2. Test Environment

- Application: `service-b`
- Application framework: Flask
- Container platform: Docker
- Consul version: `1.20.6`
- Envoy version: `v1.32-latest`
- Consul datacenter: `dev`
- Direct application endpoint: `http://localhost:5001/`
- Consul Connect/Envoy endpoint: `https://localhost:21000/`
- Latency requests: 20 per configuration
- CPU/memory samples: 10 per configuration
- Measurement tools: `curl` and `docker stats`

## 3. Test Methodology

### 3.1 Latency Measurement

Request latency was measured using `curl` with the `time_total` metric:

```bash
for i in {1..20}; do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:5001/
done
```

For the Consul Connect/Envoy path:

```bash
for i in {1..20}; do
  curl -sk -o /dev/null -w "%{time_total}\n" https://localhost:21000/
done
```

Twenty requests were performed for each configuration.

The first request was considered separately because it showed significantly higher latency due to connection and warm-up overhead.

### 3.2 CPU and Memory Measurement

Container resource usage was measured using:

```bash
docker stats --no-stream --format "{{.Name}} | CPU: {{.CPUPerc}} | MEM: {{.MemUsage}}"
```

Ten samples were collected at two-second intervals for the resource comparison.

The Consul Connect configuration included the Envoy sidecar.

The direct configuration was measured without the Envoy sidecar.

## 4. Latency Results

| Configuration | Average (20 requests) | Average excluding first request | Minimum | Maximum |
|---|---:|---:|---:|---:|
| Direct HTTP | 9.54 ms | 3.21 ms | 1.80 ms | 129.67 ms |
| Consul Connect + Envoy TLS | 9.19 ms | 4.96 ms | 3.36 ms | 89.57 ms |

### 4.1 Latency Analysis

The first request in both configurations was significantly slower than the subsequent requests. This indicates connection establishment and warm-up overhead.

Because of this, the average excluding the first request provides a more representative indication of steady-state request latency.

The measured steady-state values were:

- Direct HTTP: 3.21 ms
- Consul Connect + Envoy TLS: 4.96 ms
- Additional latency: 1.75 ms/request
- Relative increase: approximately 54.4%

The calculation is:

```text
Additional latency = 4.96 ms - 3.21 ms
                   = 1.75 ms
```

```text
Relative increase = (1.75 / 3.21) × 100
                  ≈ 54.4%
```

The Consul Connect/Envoy path therefore introduced measurable latency overhead compared with direct application access in this local Docker environment.

The overall averages were strongly affected by the first request. For this reason, the steady-state averages are more useful when comparing the two configurations.

## 5. CPU Results

### 5.1 Consul Connect Configuration

The following CPU values were collected during the 10-sample Envoy/Consul test:

| Sample | Envoy | service-b | Consul |
|---:|---:|---:|---:|
| 1 | 0.60% | 0.03% | 0.96% |
| 2 | 0.70% | 0.03% | 2.10% |
| 3 | 0.68% | 0.08% | 1.78% |
| 4 | 0.89% | 0.02% | 0.89% |
| 5 | 0.76% | 0.02% | 34.27% |
| 6 | 0.97% | 0.02% | 2.46% |
| 7 | 0.56% | 0.03% | 1.11% |
| 8 | 0.57% | 0.02% | 1.52% |
| 9 | 0.65% | 0.13% | 3.28% |
| 10 | 9.02% | 0.19% | 9.58% |

Approximate averages across the ten samples:

| Container | Average CPU |
|---|---:|
| Envoy | 1.54% |
| service-b | 0.057% |
| Consul | 5.80% |

The Consul average is influenced heavily by the 34.27% sample.

### 5.2 Direct / No-Envoy Configuration

The following CPU measurements were collected without the Envoy sidecar:

| Sample | service-a | service-b |
|---:|---:|---:|
| 1 | 0.03% | 0.06% |
| 2 | 0.09% | 0.05% |
| 3 | 0.02% | 0.02% |
| 4 | 0.03% | 0.07% |
| 5 | 0.03% | 0.02% |
| 6 | 0.05% | 0.02% |
| 7 | 0.03% | 0.05% |
| 8 | 0.09% | 0.03% |
| 9 | 0.02% | 0.03% |
| 10 | 0.04% | 0.05% |

Approximate averages:

| Container | Average CPU |
|---|---:|
| service-a | 0.043% |
| service-b | 0.040% |

### 5.3 CPU Analysis

The Envoy sidecar consumed approximately 1.54% average CPU during the sampled workload.

The application itself continued to use very little CPU. The service-b CPU average was approximately 0.057% during the Connect test compared with approximately 0.040% in the direct configuration.

This demonstrates that the Envoy proxy introduces additional CPU consumption as an additional networking and security layer.

The Consul measurements showed a significant transient spike of 34.27% during sample 5. Another higher value of 9.58% was observed during sample 10.

Because of these spikes, the Consul average should not be interpreted as continuous steady-state CPU usage.

## 6. Memory Results

### 6.1 Consul Connect Configuration

During the original 10-sample resource measurement, the following memory values were observed:

| Container | Memory Usage |
|---|---:|
| Envoy sidecar | 23.06 MiB |
| service-b | 24.23 MiB |
| Consul | 36.09 MiB |

The memory values remained stable during that particular sampling run.

### 6.2 Direct / No-Envoy Configuration

The direct configuration produced the following memory measurements:

| Container | Memory Usage |
|---|---:|
| service-a | 25.77 MiB |
| service-b | 22.27 MiB |

### 6.3 Additional Resource Observation

An additional `docker stats` observation was collected after the main measurements:

| Container | CPU | Memory |
|---|---:|---:|
| Envoy | 0.50% | 22.03 MiB |
| service-b | 0.03% | 24.02 MiB |
| Consul | 0.53% | 35.08 MiB |
| service-a | 0.05% | 24.98 MiB |

This additional observation shows that the resource usage remained in a similar range, although individual values can vary between measurements.

It is reported separately and is not mixed into the original ten-sample averages.

### 6.4 Memory Analysis

The Envoy sidecar used approximately 23.06 MiB of memory during the primary measurement.

This represents the additional memory footprint of running the Envoy proxy alongside the application.

The direct and Connect configurations used different application container layouts during the measurements. Therefore, the application memory values should not be treated as a strict one-to-one controlled memory comparison.

The clearest additional memory cost observed in the Connect configuration is the memory consumed by the Envoy sidecar itself.

## 7. Overall Performance Comparison

| Metric | Direct Configuration | Consul Connect + Envoy | Observed Difference |
|---|---:|---:|---|
| Steady-state latency | 3.21 ms | 4.96 ms | +1.75 ms |
| Relative latency | Baseline | 54.4% higher | +54.4% |
| Envoy CPU | Not applicable | 1.54% average | Additional proxy CPU |
| Envoy memory | Not applicable | 23.06 MiB | Additional proxy memory |

## 8. Performance Trade-off

The Consul Connect architecture introduces additional resource consumption because traffic passes through an Envoy sidecar and uses TLS-based service-to-service communication.

The main measured overheads were:

- Approximately 1.75 ms additional steady-state latency per request.
- Approximately 1.54% average CPU usage by the Envoy sidecar.
- Approximately 23.06 MiB memory usage by the Envoy sidecar.

These costs provide additional service-mesh capabilities such as:

- Mutual TLS (mTLS).
- Encrypted service-to-service traffic.
- Service identity.
- Certificate management.
- Traffic policy enforcement.
- Service intentions and access control.

Therefore, the performance overhead represents a trade-off for the additional security and networking capabilities provided by Consul Connect.

## 9. Limitations

This benchmark was performed in a local Docker environment using a lightweight Flask application and a relatively small number of requests.

The results may differ in production environments because of:

- Network latency.
- Application workload.
- Request and response sizes.
- Number of concurrent requests.
- Number of services.
- TLS connection reuse.
- CPU and memory availability.
- Container runtime overhead.
- Envoy configuration.
- Consul configuration.
- Host system load.

The CPU measurements were sampled at intervals rather than continuously.

The Consul CPU measurements also contained significant transient spikes, so the average should be interpreted cautiously.

The memory measurements were collected from separate test configurations and should not be interpreted as a perfectly controlled benchmark of total system memory.

Therefore, these results should be considered representative of this specific test environment and workload rather than universal performance characteristics of Consul Connect.

## 10. Conclusion

The performance comparison successfully evaluated the test application with and without the Consul Connect/Envoy service-mesh layer.

Direct HTTP access showed lower steady-state latency at approximately 3.21 ms, while the Consul Connect/Envoy TLS path averaged approximately 4.96 ms.

This resulted in approximately 1.75 ms of additional latency per request, representing an approximately 54.4% increase in steady-state latency for this test.

The Envoy sidecar consumed approximately 1.54% average CPU and 23.06 MiB of memory during the primary resource measurement.

The results demonstrate that Consul Connect introduces measurable latency and resource overhead. However, this overhead comes with additional security and networking capabilities, including mTLS, encrypted traffic, service identity, certificate management, and traffic policy enforcement.

Overall, the benchmark demonstrates the performance trade-off involved in introducing a Consul Connect service-mesh layer into the application architecture.