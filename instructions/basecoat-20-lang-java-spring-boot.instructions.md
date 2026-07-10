---
description: "Conventions for Java Spring Boot projects targeting Azure: deployment targets, containerization, database migration, auth modernization, and CI/CD patterns."
applyTo: "**/*.java,**/pom.xml,**/build.gradle,**/application.yml,**/application.properties"
---

# Java Spring Boot Standards

Use this instruction when working on Spring Boot applications deployed to Azure, including new services, migrations, containerization, and CI/CD pipelines.

## Azure Deployment Targets

Choose the runtime that best matches the packaging and operational model.

- **Azure App Service — Java SE runtime**: for self-contained executable JARs with embedded Tomcat. Set `JAVA_OPTS` in App Service configuration.
- **Azure App Service — Tomcat runtime**: for WAR deployments. Avoid this for greenfield work; prefer embedded Tomcat.
- **Azure App Service — JBoss EAP runtime**: for legacy Jakarta EE workloads that require JBoss EAP. Use only when required by existing application architecture.
- **Azure Container Apps**: preferred for containerized Spring Boot when you need autoscaling, sidecar support, or Dapr integration.
- **AKS**: for platform teams managing Kubernetes directly. Supports both JVM and GraalVM native image workloads. Use native image when cold-start latency or memory footprint is a constraint.

Include the Spring Cloud Azure BOM and relevant starters for Azure SDK integration:

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>com.azure.spring</groupId>
      <artifactId>spring-cloud-azure-dependencies</artifactId>
      <version>${spring-cloud-azure.version}</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <!-- Key Vault secrets -->
  <dependency>
    <groupId>com.azure.spring</groupId>
    <artifactId>spring-cloud-azure-starter-keyvault-secrets</artifactId>
  </dependency>
  <!-- Service Bus messaging -->
  <dependency>
    <groupId>com.azure.spring</groupId>
    <artifactId>spring-cloud-azure-starter-servicebus</artifactId>
  </dependency>
</dependencies>
```

## Containerization

Use layered JARs to minimise image rebuild cost on code-only changes.

### Layered JAR with Maven

```xml
<plugin>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-maven-plugin</artifactId>
  <configuration>
    <layers>
      <enabled>true</enabled>
    </layers>
  </configuration>
</plugin>
```

Build the OCI image directly with:

```bash
./mvnw spring-boot:build-image -Dspring-boot.build-image.imageName=myapp:latest
```

### Multi-stage Dockerfile

```dockerfile
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app
COPY . .
RUN ./mvnw -q package -DskipTests

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
ARG JAR_FILE=/app/target/*.jar
COPY --from=builder ${JAR_FILE} app.jar
EXPOSE 8080
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "app.jar"]
```

Use `mcr.microsoft.com/openjdk/jdk:21-ubuntu` (Microsoft OpenJDK) as an alternative base image when enterprise support or Microsoft-signed images are required.

### JVM tuning for containers

Always enable container-aware memory limits:

- `-XX:+UseContainerSupport` — reads cgroup limits instead of host memory.
- `-XX:MaxRAMPercentage=75.0` — caps heap at 75% of container memory; leaves headroom for metaspace and native threads.
- Add `-XX:+ExitOnOutOfMemoryError` to surface OOM crashes promptly instead of degrading silently.

### Health probe

Expose `/actuator/health` and configure liveness/readiness probes:

```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
      show-details: when-authorized
  endpoints:
    web:
      exposure:
        include: health,info,metrics
```

Map the probes in Kubernetes or Azure Container Apps to `/actuator/health/liveness` and `/actuator/health/readiness`.

## Database Migration

### Data source configuration

Read connection strings from environment variables. Never hardcode credentials.

```yaml
spring:
  datasource:
    url: ${AZURE_SQL_JDBC_URL}
    username: ${AZURE_SQL_USERNAME}
    password: ${AZURE_SQL_PASSWORD}
    hikari:
      connection-timeout: 30000
      maximum-pool-size: 10
      minimum-idle: 2
      idle-timeout: 600000
      max-lifetime: 1800000
      connection-test-query: SELECT 1
```

For Azure Database for PostgreSQL:

```yaml
spring:
  datasource:
    url: ${AZURE_POSTGRESQL_JDBC_URL}
    username: ${AZURE_POSTGRESQL_USERNAME}
    password: ${AZURE_POSTGRESQL_PASSWORD}
    hikari:
      maximum-pool-size: 5
      connection-timeout: 20000
```

### HikariCP sizing for Azure SQL

- Keep `maximum-pool-size` ≤ the DTU/vCore limit of the Azure SQL tier to avoid connection throttling.
- Set `connection-timeout` to 30 s or lower to surface connection failures fast.
- Enable SSL validation: append `;encrypt=true;trustServerCertificate=false` to the JDBC URL.

### Schema migration with Flyway

```xml
<dependency>
  <groupId>org.flywaydb</groupId>
  <artifactId>flyway-core</artifactId>
</dependency>
```

```yaml
spring:
  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
    out-of-order: false
```

Place migration scripts in `src/main/resources/db/migration/` using the naming convention `V{version}__{description}.sql`. Run Flyway as part of application startup in dev/test; in production pipelines, run `flyway migrate` as a pre-deploy step to separate schema changes from code deployment.

### Schema migration with Liquibase

```xml
<dependency>
  <groupId>org.liquibase</groupId>
  <artifactId>liquibase-core</artifactId>
</dependency>
```

```yaml
spring:
  liquibase:
    change-log: classpath:db/changelog/db.changelog-master.yaml
    enabled: true
```

## Auth Modernization

### Spring Security with Microsoft Entra ID OIDC

Add the Entra ID starter:

```xml
<dependency>
  <groupId>com.azure.spring</groupId>
  <artifactId>spring-cloud-azure-starter-active-directory</artifactId>
</dependency>
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
</dependency>
```

Configure the tenant and audience:

```yaml
spring:
  cloud:
    azure:
      active-directory:
        enabled: true
        credential:
          client-id: ${AZURE_CLIENT_ID}
          client-secret: ${AZURE_CLIENT_SECRET}
        profile:
          tenant-id: ${AZURE_TENANT_ID}
        app-id-uri: ${AZURE_APP_ID_URI}
        authorization-clients:
          graph:
            scopes: https://graph.microsoft.com/.default
```

### Security configuration

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health/**").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }
}
```

### Role claims mapping

Map Entra ID app roles to Spring Security granted authorities using the `roles` claim in the JWT:

```java
@Bean
public JwtAuthenticationConverter jwtAuthenticationConverter() {
    JwtGrantedAuthoritiesConverter converter = new JwtGrantedAuthoritiesConverter();
    converter.setAuthoritiesClaimName("roles");
    converter.setAuthorityPrefix("ROLE_");

    JwtAuthenticationConverter jwtConverter = new JwtAuthenticationConverter();
    jwtConverter.setJwtGrantedAuthoritiesConverter(converter);
    return jwtConverter;
}
```

Protect endpoints by role:

```java
.authorizeHttpRequests(auth -> auth
    .requestMatchers("/api/admin/**").hasRole("Admin")
    .requestMatchers("/api/**").hasRole("User")
    .anyRequest().authenticated()
)
```

Define app roles in the Entra ID app registration manifest and assign them to users or groups via **Enterprise applications > Users and groups**.

## CI/CD

### GitHub Actions — Maven build and App Service deploy

```yaml
name: Build and Deploy

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: temurin
          cache: maven

      - name: Build with Maven
        run: ./mvnw -q package -DskipTests

      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to Azure App Service
        uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ secrets.AZURE_WEBAPP_NAME }}
          package: target/*.jar
```

### Gradle variant

Replace the Maven build step with:

```yaml
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: temurin
          cache: gradle

      - name: Build with Gradle
        run: ./gradlew build -x test
```

### OIDC federated credentials

Use OIDC for Azure authentication — do not store long-lived client secrets in GitHub Actions secrets. Configure a federated credential on the service principal for the `main` branch:

```text
Subject: repo:<org>/<repo>:ref:refs/heads/main
```

Require `id-token: write` in the workflow permissions block.

### `.env.example`

Every repository must include an `.env.example` listing all required environment variables with placeholder values and a comment describing each variable. Never commit `.env` files containing real secrets.

```bash
# Azure SQL connection
AZURE_SQL_JDBC_URL=jdbc:sqlserver://<server>.database.windows.net:1433;database=<db>;encrypt=true;trustServerCertificate=false
AZURE_SQL_USERNAME=<username>
AZURE_SQL_PASSWORD=<password>

# Entra ID / MSAL4J
AZURE_CLIENT_ID=<app-registration-client-id>
AZURE_CLIENT_SECRET=<client-secret>
AZURE_TENANT_ID=<tenant-id>
AZURE_APP_ID_URI=api://<app-registration-client-id>

# App Service
AZURE_WEBAPP_NAME=<app-service-name>
AZURE_SUBSCRIPTION_ID=<subscription-id>
```
