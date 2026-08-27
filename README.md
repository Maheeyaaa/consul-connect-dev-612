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
