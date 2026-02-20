# Tenant API

## Overview

Simple REST API that stores tenant namespace/token pairs in memory. Operators
can
use it to discover tenants and configure routing.

## Runtime

- Language: JavaScript (Node.js)

- Framework: Express

## Environment Variables

- `SERVICE_PORT` (default: `8080`) - HTTP port.

## Endpoints

- `GET /tenants` - List tenants.

- `POST /tenants` - Add a tenant.

- `PUT /tenants/:namespace` - Update a tenant token.

- `DELETE /tenants/:namespace` - Remove a tenant.

## Request: Add Tenant

```json

{
  "namespace": "tenant-internal",
  "token": "tenant-internal"
}

```

## Response: Tenant List

```json

{
  "tenants": [
    { "namespace": "tenant-internal", "token": "tenant-internal" }
  ]
}

```

## Request: Update Tenant Token

```json

{
  "token": "tenant-internal"
}

```

## Errors

- `400` missing required fields.

- `404` tenant not found.

- `409` tenant already exists.

## Notes

- Data is stored in memory and resets on restart.

