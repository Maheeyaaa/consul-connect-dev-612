# Consul Connect — Test Application Deployment

This project demonstrates deploying a test application with and without HashiCorp Consul Connect, using Envoy as the Connect sidecar proxy.

## Project Overview

The project contains two simple test services and two deployment configurations:

Without Consul Connect: The application runs directly and is accessed through its exposed application port.
With Consul Connect: The application runs with an Envoy sidecar proxy, with Consul providing service registration, configuration discovery, and mTLS identity.

## Project Structure

```text
dev-612/
├── consul/
│   └── config/
│       ├── consul.hcl
│       └── service-b.json
├── envoy/
│   └── envoy-b-bootstrap.json
├── service-a/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── service-b/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── docker-compose.yml
├── docker-compose-no-consul.yml
└── .gitignore
```

## Technologies Used

* Docker
* Docker Compose
* HashiCorp Consul 1.20
* Envoy Proxy
* Python / Flask
* Consul Connect
* mTLS
* xDS / ADS configuration

## Deployment Without Consul Connect

The `docker-compose-no-consul.yml` configuration runs the test application without Consul Connect or an Envoy sidecar.

Start the deployment with:

```bash
docker compose -f docker-compose-no-consul.yml up -d
```

The application can then be tested using:

```bash
curl http://localhost:5001/
```

Expected response:

```text
Hello service B
```

## Deployment With Consul Connect

The main `docker-compose.yml` configuration includes:

* Consul
* `service-b`
* Envoy sidecar for `service-b`

Start the deployment with:

```bash
docker compose up -d
```

Consul is available on:

```text
http://localhost:8500
```

The Envoy admin interface is available on:

```text
http://localhost:19000
```

The Connect proxy listens on:

```text
https://localhost:21000
```

## Consul Service Registration

The application registers `service-b` with Consul, and Consul creates a Connect sidecar proxy:

```text
service-b
service-b-sidecar-proxy
```

The sidecar is configured as a Connect proxy for `service-b` and forwards traffic to the local application on port `5000`.

Service registration can be verified with:

```bash
curl -s http://localhost:8500/v1/agent/services | python3 -m json.tool
```

The service catalog can be checked with:

```bash
curl -s http://localhost:8500/v1/catalog/service/service-b | python3 -m json.tool
```

## Consul Connect mTLS

Consul issues an identity certificate for the service. The certificate can be inspected using:

```bash
curl -s http://localhost:8500/v1/agent/connect/ca/leaf/service-b | python3 -m json.tool
```

The certificate contains a SPIFFE URI identifying `service-b`.

Example identity format:

```text
spiffe://<consul-cluster-id>.consul/ns/default/dc/dev/svc/service-b
```

The certificate has a limited validity period and is managed by Consul Connect.

## Envoy Configuration Verification

Envoy receives its dynamic configuration from Consul through ADS/xDS.

The Envoy admin API can be queried with:

```bash
curl -s http://localhost:19000/config_dump > envoy-config.json
```

The active clusters can be inspected using:

```bash
curl -s http://localhost:19000/clusters
```

The Connect listener and authorization configuration can be inspected from the Envoy configuration dump.

The Connect listener uses TLS and an Envoy RBAC filter for Connect authorization.

## Verification Results

### Without Consul Connect

```text
curl http://localhost:5001/

→ Hello service B
```

The application is directly reachable and responds successfully.

### With Consul Connect

The following were verified:

* Consul is running successfully.
* `service-b` is registered with Consul.
* `service-b-sidecar-proxy` is registered as a Connect proxy.
* The Connect proxy points to `service-b` on port `5000`.
* Consul successfully issues a Connect identity certificate.
* Envoy successfully connects to Consul's xDS/ADS endpoint.
* Envoy dynamically receives the Connect listener configuration.
* The Connect listener is configured with TLS.
* The Envoy cluster for the local application is healthy.

A direct request to the Connect listener using plain HTTP is rejected because the listener expects TLS.

A TLS request successfully completes the TLS handshake with Envoy, confirming that the Connect TLS configuration is active. The test request itself does not return the application response because the listener is configured for Connect traffic rather than a normal direct HTTP request.

## Architecture

### Without Consul Connect

```text
Client
  │
  │ HTTP :5001
  ▼
service-b :5000
```

### With Consul Connect

```text
                    ┌──────────────┐
                    │   Consul     │
                    │    :8500     │
                    └──────┬───────┘
                           │
                       xDS / ADS
                           │
                           ▼
Client ── TLS ──► Envoy Sidecar :21000
                       │
                       │
                       ▼
                 service-b :5000
```

## Task

Deploy test application with and without Consul Connect

This repository contains the configuration and test application used to demonstrate both deployment modes.

# Recommendation: When to Use a Service Mesh

## 1. Overview

A service mesh is a dedicated infrastructure layer that manages communication between services. Consul Connect uses sidecar proxies such as Envoy to provide features including mutual TLS (mTLS), service identity, service discovery, traffic management, and access control.

A service mesh should be introduced when these capabilities provide enough operational or security value to justify the additional latency, CPU, memory, and configuration overhead.

## 2. When a Service Mesh Is Recommended

### 2.1 Multiple Microservices

A service mesh is most useful in applications containing multiple independently deployed services.

As the number of services increases, managing service-to-service communication, security, discovery, and access policies manually becomes more difficult.

A service mesh provides a centralized approach to these concerns without requiring every application to implement them independently.

### 2.2 Strong Service-to-Service Security Requirements

A service mesh is recommended when internal service communication requires strong security guarantees.

Consul Connect provides:

- Mutual TLS (mTLS)
- Encrypted service-to-service traffic
- Service identity
- Certificate management
- Identity-based access control

This is particularly useful when services communicate across different hosts, networks, or environments.

### 2.3 Zero-Trust Architecture

A service mesh can be useful when an organization follows a zero-trust security model.

Instead of trusting services based only on network location, communication can be authenticated using service identities and controlled through explicit access policies.

This allows organizations to define which services are permitted to communicate with one another.

### 2.4 Complex Traffic Management

A service mesh is useful when applications require advanced traffic-management capabilities such as:

- Service discovery
- Load balancing
- Traffic routing
- Service failover
- Health-aware routing
- Controlled communication between services

These capabilities become increasingly valuable as an application grows in complexity.

### 2.5 Observability Requirements

A service mesh can provide a consistent layer for monitoring service-to-service communication.

This can help teams understand:

- Request latency
- Service communication patterns
- Connection failures
- Traffic behavior
- Service dependencies

This is useful for troubleshooting distributed applications where communication occurs across many services.

## 3. When a Service Mesh May Not Be Necessary

A service mesh may be unnecessary for small or simple applications.

Examples include:

- A single-service application
- A small application with only a few services
- Local development environments
- Applications with very low traffic
- Systems where simple networking is sufficient
- Applications with strict resource constraints

In these situations, the operational complexity and resource overhead of a service mesh may outweigh its benefits.

## 4. Performance Considerations

The performance benchmark performed for this project showed that Consul Connect + Envoy introduced measurable overhead compared with direct HTTP communication.

The observed steady-state latency was:

- Direct HTTP: approximately 3.21 ms
- Consul Connect + Envoy TLS: approximately 4.96 ms
- Additional latency: approximately 1.75 ms/request

The Envoy sidecar also consumed additional resources, with approximately 1.54% average CPU and 23.06 MiB memory observed during the primary resource measurement.

These results demonstrate that a service mesh introduces overhead. However, the overhead should be evaluated against the security, reliability, and operational benefits required by the application.

## 5. Recommendation

A service mesh is recommended when an application has enough service-to-service communication complexity that centralized security, service discovery, traffic management, and observability provide significant value.

For small applications, the additional complexity may not be justified.

For larger microservice-based systems, especially those requiring encrypted communication, identity-based access control, zero-trust networking, or advanced traffic management, a service mesh can provide substantial operational and security benefits.

## 6. Decision Guidelines

| Application Scenario | Recommendation |
|---|---|
| Single-service application | Generally do not use a service mesh |
| Small application with a few services | Usually unnecessary |
| Growing microservice architecture | Consider introducing a service mesh |
| Many independently deployed services | Recommended |
| Strong service-to-service security requirements | Recommended |
| Zero-trust architecture | Recommended |
| Advanced traffic management requirements | Recommended |
| Cross-host or distributed service communication | Consider/Recommended |
| Very resource-constrained environment | Evaluate carefully |
| High-performance application with extremely low latency requirements | Benchmark before adoption |

## 7. Conclusion

A service mesh should not be introduced simply because an application uses microservices. The decision should be based on the application's security, networking, operational, and observability requirements.

For small and simple systems, direct communication may be easier to operate and may provide better performance.

For larger distributed systems, Consul Connect can justify its additional resource and latency overhead by providing mTLS, encrypted communication, service identity, access control, service discovery, and traffic-management capabilities.

The recommended approach is therefore to adopt a service mesh when the operational and security benefits outweigh the additional complexity and performance overhead.
