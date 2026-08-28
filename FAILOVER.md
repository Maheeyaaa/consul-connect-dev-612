# Consul Connect Failover and Load Balancing Test

This test evaluates service discovery, multiple service instances, and failover behavior using HashiCorp Consul.

## Test Environment

* Service: `service-b`
* Consul: `1.20.6`
* Deployment: Docker Compose
* Docker network: `dev-612_default`
* Consul API: `http://localhost:8500`
* Application port: `5000`

## Multiple Service Instances

A second `service-b` container was started on the same Docker network:

```bash
docker run -d \
  --name service-b-2 \
  --network dev-612_default \
  dev-612-service-b
```

The second container was assigned the Docker IP address:

```text
172.18.0.5
```

It was manually registered with Consul using the same service name but a unique service ID:

```bash
curl -X PUT \
  --data '{
    "ID": "service-b-2",
    "Name": "service-b",
    "Address": "172.18.0.5",
    "Port": 5000
  }' \
  http://localhost:8500/v1/agent/service/register
```

Consul service discovery then returned two instances:

```text
service-b
service-b-2
```

The two instances were:

```text
service-b     :5000
service-b-2   172.18.0.5:5000
```

This confirms that Consul can maintain multiple instances under the same service name.

## Service Discovery and Load-Balancing Verification

The passing service instances were queried using:

```bash
for i in {1..20}; do
  curl -s "http://localhost:8500/v1/health/service/service-b?passing" | \
  python3 -c 'import sys,json; d=json.load(sys.stdin); print([(x["Service"]["ID"], x["Service"]["Address"], x["Service"]["Port"]) for x in d])'
done
```

All 20 queries returned both registered instances:

```text
[('service-b', '', 5000), ('service-b-2', '172.18.0.5', 5000)]
```

This demonstrates that Consul consistently discovered both available instances.

> Note: This test verifies multi-instance service discovery. It does not directly measure request-level load-balancing distribution because the application endpoint used in this setup does not expose which backend instance handled each request.

## Failover Test

The second service instance was stopped:

```bash
docker stop service-b-2
```

The passing service instances were then checked again:

```bash
curl -s "http://localhost:8500/v1/health/service/service-b?passing" | python3 -m json.tool
```

After the second container was stopped, only the original `service-b` instance appeared in the passing service list.

The stopped `service-b-2` instance was therefore no longer included among the passing services.

An attempt to explicitly deregister `service-b-2` returned:

```text
Unknown service ID "service-b-2".
Ensure that the service ID is passed, not the service name.
```

This occurred because the service was already absent from the agent's registered service list after the container was stopped.

## Remaining Service Verification

The remaining `service-b` instance was tested directly:

```bash
curl http://localhost:5001/
```

Response:

```text
Hello service B
```

The application continued responding successfully after the second service instance was stopped.

## Results

| Test                                        | Result                                    |
| ------------------------------------------- | ----------------------------------------- |
| Start second `service-b` instance           | Successful                                |
| Register second instance with Consul        | Successful                                |
| Discover both service instances             | Successful                                |
| Repeated service discovery test             | Both instances returned in all 20 queries |
| Stop second service instance                | Successful                                |
| Passing service list after failure          | Only original `service-b` remained        |
| Remaining service availability              | Successful                                |
| Application response after instance failure | `Hello service B`                         |

## Analysis

The test demonstrated that Consul can register and discover multiple instances of the same service.

Before the failure test, Consul consistently returned both `service-b` and `service-b-2` as available instances across 20 service discovery queries.

After `service-b-2` was stopped, the passing service query returned only the original `service-b` instance. The remaining service continued to respond successfully to requests.

This demonstrates the basic failover behavior expected from a service-discovery system: when one service instance becomes unavailable, an available instance can continue serving traffic.

The second instance was manually registered without an explicit application-level health check. Therefore, this test should not be interpreted as a full production health-check configuration. The observed removal from the passing service list occurred after the stopped instance was no longer available to Consul.

The load-balancing portion of the test confirms that Consul maintains multiple available service instances, but it does not prove equal request distribution between the instances. A request-level load-balancing test would require routing requests through a proxy or client that uses Consul service discovery and recording which instance handles each request.

## Conclusion

The failover and service-discovery test was successfully completed.

The test confirmed that:

* Multiple instances of `service-b` can be registered with Consul.
* Consul successfully discovers multiple available instances.
* The service discovery result changes when an instance becomes unavailable.
* The remaining service instance continues serving requests after another instance is stopped.
* Consul provides the service-discovery information required for load balancing and failover.

The results demonstrate the basic service discovery and failover capabilities relevant to a Consul-based service deployment.
