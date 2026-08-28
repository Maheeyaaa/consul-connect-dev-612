# Consul Connect Latency Benchmark

This benchmark compares request latency between the test application running directly and the same application accessed through the Consul Connect/Envoy sidecar path.

## Test Environment

- Application: `service-b`
- Direct application endpoint: `http://localhost:5001/`
- Consul Connect/Envoy endpoint: `https://localhost:21000/`
- Number of requests: 20 per configuration
- Measurement tool: `curl`
- Metric: `time_total`

## Test Method

### Without Consul Connect

Requests were sent directly to the application:

```bash
for i in {1..20}; do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:5001/
done