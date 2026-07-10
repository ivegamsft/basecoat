# Enterprise .NET Development Guidance

This document provides best practices for .NET development in enterprise environments.

## .NET Runtime Selection

Choose runtime based on workload requirements:

| Runtime | Support End | Use Case |
|---|---|---|
| **.NET Framework 4.8** | 2029 | Legacy Windows-only apps |
| **.NET 6** | May 2024 | Upgrade to .NET 8 |
| **.NET 8 (LTS)** | Nov 2026 | Production default |

## .NET Framework Lifecycle

**.NET Framework 4.8** reaches end of support in January 2029. During extended support (until then), only critical security patches are released.

### Migration Strategy

Use strangler fig pattern to incrementally migrate from Framework to .NET Core:

1. Deploy reverse proxy (Application Gateway)
2. Build new services in .NET 8
3. Route traffic gradually (10% → 50% → 100%)
4. Decommission Framework when complete

## .NET 8 Best Practices

- Use dependency injection from built-in container
- Always use async/await for I/O
- Use Entity Framework Core for data access
- Configure per-environment settings via appsettings
- Implement proper error handling and logging

## Entity Framework Core

Use EF Core for data access with strongly-typed DbContext:

`csharp
public class AppDbContext : DbContext
{
    public DbSet<Order> Orders { get; set; }
    public DbSet<OrderItem> OrderItems { get; set; }
}

// Migrations maintain schema as code
dotnet ef migrations add AddOrders
dotnet ef database update
`

## Base Coat Assets

- Agent: \gents/dotnet-modernization-advisor.agent.md\
- Skill: \skills/entity-framework-migration/\

## References

- [.NET Support Policy](https://dotnet.microsoft.com/support/policy)
- [Entity Framework Core](https://docs.microsoft.com/ef/core/)
