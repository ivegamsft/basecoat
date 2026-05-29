---
description: "Use when migrating J2EE / Jakarta EE applications. Covers namespace migration, EJB modernization, Azure deployment targets, Strangler Fig decomposition, database migration, and auth modernization."
applyTo: "**/ejb-jar.xml,**/persistence.xml,**/*.war,**/web.xml,**/jboss*.xml"
---

# J2EE / Jakarta EE Migration

Use this instruction when AI is assisting with J2EE or Jakarta EE workloads — legacy EJB modernization,
namespace migration to Jakarta EE 10, or migration onto Azure-hosted runtimes.

## Namespace Migration

Migrate all `javax.*` imports to `jakarta.*` as required by Jakarta EE 9+.

- `javax.ejb.*` → `jakarta.ejb.*`
- `javax.persistence.*` → `jakarta.persistence.*`
- `javax.servlet.*` → `jakarta.servlet.*`
- `javax.transaction.*` → `jakarta.transaction.*`
- `javax.xml.bind.*` → `jakarta.xml.bind.*`

Prefer automated tooling over manual search-and-replace:

- **OpenRewrite**: apply the `org.openrewrite.java.migrate.jakarta.JavaxMigrationToJakarta` recipe.

```xml
<plugin>
  <groupId>org.openrewrite.maven</groupId>
  <artifactId>rewrite-maven-plugin</artifactId>
  <version>5.x</version>
  <configuration>
    <activeRecipes>
      <recipe>org.openrewrite.java.migrate.jakarta.JavaxMigrationToJakarta</recipe>
    </activeRecipes>
  </configuration>
</plugin>
```

- **Eclipse Transformer**: use for WAR/JAR binary transformation when source is unavailable.

After migration, validate that no `javax.*` references remain in source or configuration files.

## EJB Modernization

Replace EJB session beans with lightweight alternatives:

- **Stateless session beans** → Spring `@Service` beans or Azure Functions for event-driven workloads.
- **Stateful session beans** → externalize state to Azure Cache for Redis; use a stateless service layer.
- **Container-managed transactions (CMT/JTA)** → Spring `@Transactional` with a `PlatformTransactionManager`,
  or explicit `TransactionTemplate` for programmatic control.
- **JNDI datasource lookups** → environment variable–driven JDBC URLs with HikariCP connection pooling.

Example: replacing a JNDI lookup with environment-variable configuration:

```java
// Before: JNDI lookup
DataSource ds = (DataSource) new InitialContext().lookup("java:comp/env/jdbc/mydb");

// After: HikariCP from environment variables
HikariConfig config = new HikariConfig();
config.setJdbcUrl(System.getenv("JDBC_URL"));
config.setUsername(System.getenv("DB_USER"));
config.setPassword(System.getenv("DB_PASSWORD"));
DataSource ds = new HikariDataSource(config);
```

Never embed connection strings in `web.xml`, `ejb-jar.xml`, or application server configuration files.

## Azure Deployment Targets

Choose the runtime that matches the migration stage:

- **Azure App Service — JBoss EAP runtime**: lift-and-shift for apps that cannot migrate quickly;
  supports EAR deployments and full JTA. Use as a transitional target only.
- **Azure App Service — Tomcat runtime**: servlet/JSP apps migrated to Servlet 5+ (Jakarta EE 9+).
  Suitable after EJB logic has been extracted to a service layer.
- **Azure Container Apps**: containerized WildFly, Quarkus, or Spring Boot after full migration.
  Preferred for greenfield modernization paths.
- **Azure Red Hat OpenShift (ARO)**: JBoss EAP workloads requiring full J2EE compatibility
  and operator-managed lifecycle; suited for large enterprise portfolios with long migration runways.

Document the target runtime in every deployment configuration PR. Include the migration stage
(lift-and-shift / partial / full) so reviewers understand the trade-offs.

## Strangler Fig Pattern

Incrementally extract EJB services to REST microservices without a big-bang rewrite:

1. Identify a bounded EJB service with a clear interface boundary.
2. Implement an equivalent REST endpoint (Spring MVC, Quarkus REST, or Azure Function).
3. Route a percentage of traffic to the new endpoint via Azure Application Gateway or API Management.
4. Monitor error rates and latency before increasing the traffic share.
5. Retire the EJB service once traffic is fully cut over and rollback window has passed.

For session state migration:

- Map stateful EJB attributes to a Redis hash keyed on a session or correlation ID.
- Use Spring Session with Azure Cache for Redis to transparently externalize `HttpSession`.
- Validate session continuity across the cutover boundary before retiring stateful EJBs.

## Database Migration

- Replace every JNDI `DataSource` lookup with an environment variable–driven JDBC URL (see EJB Modernization above).
- Migrate EJB 2.x entity beans to JPA 3.x `@Entity` classes; avoid generated CMP descriptors.
- Use Spring JDBC `JdbcTemplate` or `SimpleJdbcCall` for stored procedure calls that cannot be
  replaced by JPA.
- Configure HikariCP with explicit pool sizing, connection timeout, and idle timeout:

```properties
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.max-lifetime=1800000
```

- Never set `maximum-pool-size` without understanding the database server's max connection limit.

## Auth Modernization

Replace JAAS and container-managed security with Entra ID:

- Remove `<security-domain>` references from `jboss-web.xml` and `web.xml`.
- Register the application in Entra ID and configure OIDC with the Microsoft Identity Platform.
- Use Spring Security's `oauth2Login` or Quarkus OIDC extension for the authentication flow.
- Map application server security roles to Entra ID app roles:

```yaml
# application.yml (Spring Boot)
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://login.microsoftonline.com/<tenant-id>/v2.0
```

- Enforce role claims in `@PreAuthorize` annotations rather than in `web.xml` `<security-constraint>` blocks.
- Never replicate JAAS `LoginModule` logic in the new application; delegate entirely to Entra ID.
