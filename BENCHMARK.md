# Consul Connect Latency Benchmark

This benchmark compares request latency between the test application running directly and the same application accessed through the Consul Connect/Envoy sidecar path.

## Test Environment

Application: `service-b`
Direct application endpoint: `http://localhost:5001/`
Consul Connect/Envoy endpoint: `https://localhost:21000/`
Number of requests: 20 per configuration
Measurement tool: `curl`
Metric: `time_total`

## Test Method

### Without Consul Connect

Requests were sent directly to the application:

```bash
for i in {1..20}; do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:5001/
done
```

### With Consul Connect + Envoy TLS

Requests were sent through the Consul Connect/Envoy TLS listener:

```bash
for i in {1..20}; do
  curl -sk -o /dev/null -w "%{time_total}\n" https://localhost:21000/
done
```

## Results

| Configuration              | Average (20 requests) | Average excluding first request | Minimum |   Maximum |
| -------------------------- | --------------------: | ------------------------------: | ------: | --------: |
| Direct HTTP                |               9.54 ms |                         3.21 ms | 1.80 ms | 129.67 ms |
| Consul Connect + Envoy TLS |               9.19 ms |                         4.96 ms | 3.36 ms |  89.57 ms |

## Analysis

The first request in each test was significantly slower than the subsequent requests, indicating connection and warm-up overhead. Therefore, the average excluding the first request provides a more representative comparison of steady-state request latency.

After excluding the first request:

Direct HTTP latency: approximately 3.21 ms
Consul Connect + Envoy TLS latency: approximately 4.96 ms
Additional latency: approximately 1.75 ms per request
Relative increase: approximately 54.4%

The benchmark indicates that the Consul Connect/Envoy path introduces additional request latency compared with direct application access in this local Docker environment.

This overhead is associated with the additional proxy and TLS processing in the Connect path. The result should be considered specific to this test environment and workload rather than a universal performance characteristic of Consul Connect.

## Conclusion

The test application was successfully benchmarked with and without Consul Connect.

Direct application access showed lower steady-state latency, while requests through the Consul Connect/Envoy TLS path introduced approximately 1.75 ms of additional latency per request in this test.

The benchmark demonstrates the latency trade-off associated with adding the Consul Connect service-mesh security and proxy layer.
