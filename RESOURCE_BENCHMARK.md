# Consul Connect Envoy Sidecar Resource Benchmark

This benchmark measures the CPU and memory overhead introduced by the Envoy sidecar when running `service-b` with Consul Connect.

## Test Environment

* Application: `service-b`
* Without Consul Connect: Direct Docker deployment
* With Consul Connect: `service-b` with Envoy sidecar
* Number of resource samples: 10 per configuration
* Sampling interval: 2 seconds
* Measurement tool: Docker `stats`
* CPU metric: Container CPU utilization
* Memory metric: Container memory usage

## Test Method

### Without Consul Connect

The application was deployed without Consul Connect:

```bash
docker compose down
docker compose -f docker-compose-no-consul.yml up -d
```

Resource usage was measured using:

```bash
for i in {1..10}; do
  echo "Sample $i"
  docker stats --no-stream --format "{{.Name}} | CPU: {{.CPUPerc}} | MEM: {{.MemUsage}}"
  sleep 2
done
```

The `service-b` container was used as the baseline.

### With Consul Connect + Envoy

The application was deployed with Consul Connect and the Envoy sidecar.

Resource usage was measured using the same Docker `stats` command over 10 samples.

The resource usage of both `service-b` and `envoy-b` was recorded.

## Results

| Configuration       | Average CPU |    Memory |
| ------------------- | ----------: | --------: |
| Direct `service-b`  |       0.04% | 22.27 MiB |
| `service-b` + Envoy |       0.04% | 24.23 MiB |
| Envoy sidecar       |       1.50% | 23.06 MiB |

The average Envoy CPU utilization was calculated from the following samples:

`0.60%, 0.70%, 0.68%, 0.89%, 0.76%, 0.97%, 0.56%, 0.57%, 0.65%, 9.02%`

The average `service-b` CPU utilization without the sidecar was:

`0.06%, 0.05%, 0.02%, 0.07%, 0.02%, 0.02%, 0.05%, 0.03%, 0.03%, 0.05%`

The memory usage remained stable during the measurements.

## Analysis

The Envoy sidecar consumed approximately 23.06 MiB of memory in this test environment.

The direct `service-b` container used approximately 22.27 MiB, while `service-b` with the Envoy sidecar showed approximately 24.23 MiB of memory usage.

The Envoy container itself accounted for the additional sidecar resource footprint.

The average Envoy CPU utilization was approximately 1.50% across the 10 samples. A temporary CPU spike of 9.02% was observed during the final sample, demonstrating that CPU utilization can vary during container operation.

The direct `service-b` container averaged approximately 0.04% CPU utilization.

These measurements represent an idle/light-load local Docker environment. CPU usage can vary depending on traffic volume, request patterns, TLS processing, Envoy configuration, and the host environment.

## Conclusion

The test successfully measured the resource overhead associated with running an Envoy sidecar for `service-b`.

In this test environment, the Envoy sidecar consumed approximately 23.06 MiB of memory and averaged approximately 1.50% CPU utilization.

The results demonstrate that Consul Connect with an Envoy sidecar introduces a measurable resource footprint compared with direct application deployment.

The measured overhead is specific to this local Docker environment and workload and should not be treated as a universal resource requirement for Envoy or Consul Connect.
