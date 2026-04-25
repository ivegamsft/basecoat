# API Specification Template

Use this template to define an API contract before implementation begins. Fill in all sections. Leave no section blank — use `N/A` if a section does not apply.

---

## API Overview

| Field | Value |
|---|---|
| **API Name** | `<service-name> API` |
| **Version** | `v1` |
| **Base Path** | `/v1/<resource>` |
| **Auth Scheme** | Bearer token / API key / OAuth 2.0 / None |
| **Owner** | `<team or service name>` |
| **Last Updated** | `YYYY-MM-DD` |

---

## OpenAPI 3.x Skeleton

```yaml
openapi: "3.0.3"
info:
  title: "<Service Name> API"
  version: "1.0.0"
  description: "<One-sentence description of what this API does.>"

servers:
  - url: "https://api.example.com/v1"
    description: Production
  - url: "https://api-staging.example.com/v1"
    description: Staging

security:
  - BearerAuth: []

paths:
  /<resource>:
    get:
      summary: "List <resources>"
      operationId: "list<Resource>"
      tags:
        - <Resource>
      parameters:
        - name: pageSize
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
        - name: cursor
          in: query
          schema:
            type: string
      responses:
        "200":
          description: "Paginated list of <resources>"
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/<Resource>ListResponse"
        "400":
          $ref: "#/components/responses/BadRequest"
        "401":
          $ref: "#/components/responses/Unauthorized"
        "500":
          $ref: "#/components/responses/InternalServerError"

    post:
      summary: "Create a <resource>"
      operationId: "create<Resource>"
      tags:
        - <Resource>
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/Create<Resource>Request"
      responses:
        "201":
          description: "<Resource> created"
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/<Resource>"
        "400":
          $ref: "#/components/responses/BadRequest"
        "401":
          $ref: "#/components/responses/Unauthorized"
        "422":
          $ref: "#/components/responses/ValidationError"
        "500":
          $ref: "#/components/responses/InternalServerError"

  /<resource>/{id}:
    get:
      summary: "Get a <resource> by ID"
      operationId: "get<Resource>"
      tags:
        - <Resource>
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        "200":
          description: "<Resource> found"
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/<Resource>"
        "401":
          $ref: "#/components/responses/Unauthorized"
        "404":
          $ref: "#/components/responses/NotFound"
        "500":
          $ref: "#/components/responses/InternalServerError"

    patch:
      summary: "Update a <resource>"
      operationId: "update<Resource>"
      tags:
        - <Resource>
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/Update<Resource>Request"
      responses:
        "200":
          description: "<Resource> updated"
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/<Resource>"
        "400":
          $ref: "#/components/responses/BadRequest"
        "401":
          $ref: "#/components/responses/Unauthorized"
        "404":
          $ref: "#/components/responses/NotFound"
        "422":
          $ref: "#/components/responses/ValidationError"
        "500":
          $ref: "#/components/responses/InternalServerError"

    delete:
      summary: "Delete a <resource>"
      operationId: "delete<Resource>"
      tags:
        - <Resource>
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        "204":
          description: "<Resource> deleted"
        "401":
          $ref: "#/components/responses/Unauthorized"
        "404":
          $ref: "#/components/responses/NotFound"
        "500":
          $ref: "#/components/responses/InternalServerError"

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    <Resource>:
      type: object
      required:
        - id
        - createdAt
        - updatedAt
      properties:
        id:
          type: string
          format: uuid
        createdAt:
          type: string
          format: date-time
        updatedAt:
          type: string
          format: date-time
        # Add domain-specific properties here

    Create<Resource>Request:
      type: object
      required:
        - # list required fields
      properties:
        # Add create-request properties here

    Update<Resource>Request:
      type: object
      properties:
        # Add update-request properties here (all optional for PATCH)

    <Resource>ListResponse:
      type: object
      required:
        - data
        - pagination
      properties:
        data:
          type: array
          items:
            $ref: "#/components/schemas/<Resource>"
        pagination:
          $ref: "#/components/schemas/PaginationMeta"

    PaginationMeta:
      type: object
      required:
        - total
        - pageSize
      properties:
        total:
          type: integer
        pageSize:
          type: integer
        nextCursor:
          type: string
          nullable: true

    ErrorEnvelope:
      type: object
      required:
        - error
      properties:
        error:
          type: object
          required:
            - code
            - message
            - correlationId
          properties:
            code:
              type: string
              example: "VALIDATION_FAILED"
            message:
              type: string
            details:
              type: array
              items:
                type: object
                properties:
                  field:
                    type: string
                  issue:
                    type: string
            correlationId:
              type: string
              format: uuid

  responses:
    BadRequest:
      description: "Bad request — malformed input"
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
    Unauthorized:
      description: "Unauthenticated — missing or invalid credentials"
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
    NotFound:
      description: "Resource not found"
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
    ValidationError:
      description: "Unprocessable entity — validation failure"
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
    InternalServerError:
      description: "Internal server error"
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/ErrorEnvelope"
```

---

## Endpoint Summary

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/v1/<resource>` | Required | List with pagination |
| `POST` | `/v1/<resource>` | Required | Create |
| `GET` | `/v1/<resource>/{id}` | Required | Get by ID |
| `PATCH` | `/v1/<resource>/{id}` | Required | Partial update |
| `DELETE` | `/v1/<resource>/{id}` | Required | Delete |

## Breaking vs Non-Breaking Changes

| Change type | Breaking? |
|---|---|
| Add optional field to request/response | No |
| Remove a field | Yes |
| Change a field type | Yes |
| Add a new endpoint | No |
| Change HTTP method or path | Yes |
| Remove an endpoint | Yes |
