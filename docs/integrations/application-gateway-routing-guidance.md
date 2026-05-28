# Application Gateway Multi-Application Routing Guidance

This document provides best practices for using Azure Application Gateway to route traffic to multiple backend applications, including listener configuration, path-based routing, and host-based routing patterns.

## Application Gateway Architecture

### Core Components

```
Clients
  |
  v
[Application Gateway]
  |
  +-- Frontend IP (Public)
  +-- Listeners
  +-- Rules
  +-- Backend Pools
  +-- HTTP Settings
  +-- Probes
```

Key components:

- **Frontend IP**: Public IP receiving incoming requests
- **Listeners**: Port and protocol binding (HTTP/HTTPS)
- **Routing Rules**: HTTP(S) rules mapping listeners to backend pools
- **Backend Pools**: Groups of backend resources (VMs, App Service, containers)
- **HTTP Settings**: Connection protocol, timeout, cookie affinity
- **Health Probes**: Monitor backend health; remove unhealthy instances

### SKU Selection

Choose based on throughput and features:

| SKU | Max Throughput | WAF | Multi-Site | Auto-Scale |
|---|---|---|---|---|
| **Standard** | 1,250 Mbps | No | Yes | No |
| **Standard_v2** | 2,500 Mbps | No | Yes | Yes |
| **WAF_v2** | 2,500 Mbps | Yes | Yes | Yes |

## Multi-Application Routing Patterns

### Pattern 1: Host-Based Routing

Route based on Host header (hostname):

```powershell
# Backend pools for each app
$pool1 = New-AzApplicationGatewayBackendAddressPool -Name 'web-app-pool' -BackendAddresses @('10.0.1.10')
$pool2 = New-AzApplicationGatewayBackendAddressPool -Name 'api-pool' -BackendAddresses @('10.0.2.10')
$pool3 = New-AzApplicationGatewayBackendAddressPool -Name 'admin-pool' -BackendAddresses @('10.0.3.10')

# HTTP listeners for each hostname
$listener1 = New-AzApplicationGatewayHttpListener `
  -Name 'web-listener' `
  -FrontendIPConfiguration $fipConfig `
  -FrontendPort $port `
  -Protocol 'Http' `
  -HostName 'www.example.com'

$listener2 = New-AzApplicationGatewayHttpListener `
  -Name 'api-listener' `
  -FrontendIPConfiguration $fipConfig `
  -FrontendPort $port `
  -Protocol 'Http' `
  -HostName 'api.example.com'

# Rules mapping listeners to pools
$rule1 = New-AzApplicationGatewayRequestRoutingRule `
  -Name 'web-rule' `
  -RuleType 'Basic' `
  -HttpListener $listener1 `
  -BackendAddressPool $pool1 `
  -HttpSettings $httpSettings

$rule2 = New-AzApplicationGatewayRequestRoutingRule `
  -Name 'api-rule' `
  -RuleType 'Basic' `
  -HttpListener $listener2 `
  -BackendAddressPool $pool2 `
  -HttpSettings $httpSettings
```

### Pattern 2: Path-Based Routing

Route based on URL path (/api/*, /admin/*, etc.):

```powershell
# URL path map defines routing by prefix
$urlPathMap = New-AzApplicationGatewayUrlPathMap `
  -Name 'url-path-map' `
  -DefaultBackendAddressPool $defaultPool `
  -DefaultBackendHttpSettings $httpSettings

# Add path rules
$pathRule1 = New-AzApplicationGatewayPathRule `
  -Name 'api-path' `
  -Paths '/api/*' `
  -BackendAddressPool $apiPool `
  -BackendHttpSettings $httpSettings

$pathRule2 = New-AzApplicationGatewayPathRule `
  -Name 'admin-path' `
  -Paths '/admin/*' `
  -BackendAddressPool $adminPool `
  -BackendHttpSettings $httpSettings

$urlPathMap = Update-AzApplicationGatewayUrlPathMap `
  -ApplicationGateway $appGw `
  -UrlPathMap $urlPathMap `
  -PathRules @($pathRule1, $pathRule2)

# Create path-based routing rule
$rule = New-AzApplicationGatewayRequestRoutingRule `
  -Name 'path-routing-rule' `
  -RuleType 'PathBasedRouting' `
  -HttpListener $listener `
  -UrlPathMap $urlPathMap
```

### Pattern 3: Multi-Site Host-Based with HTTPS

Route HTTPS traffic to multiple applications by hostname:

```powershell
# Load SSL certificate
$cert = New-AzApplicationGatewaySslCertificate `
  -Name 'appgw-cert' `
  -CertificateFile 'C:\certs\certificate.pfx' `
  -Password (ConvertTo-SecureString 'password' -AsPlainText -Force)

# HTTPS frontend port
$httpsPort = New-AzApplicationGatewayFrontendPort `
  -Name 'https' `
  -Port 443 `
  -Protocol 'Https'

# HTTPS listeners for each application
$listener1 = New-AzApplicationGatewayHttpListener `
  -Name 'web-https-listener' `
  -FrontendIPConfiguration $fipConfig `
  -FrontendPort $httpsPort `
  -Protocol 'Https' `
  -SslCertificate $cert `
  -HostName 'www.example.com'

$listener2 = New-AzApplicationGatewayHttpListener `
  -Name 'api-https-listener' `
  -FrontendIPConfiguration $fipConfig `
  -FrontendPort $httpsPort `
  -Protocol 'Https' `
  -SslCertificate $cert `
  -HostName 'api.example.com'

# Redirect HTTP to HTTPS
$rule = New-AzApplicationGatewayRequestRoutingRule `
  -Name 'redirect-rule' `
  -RuleType 'Basic' `
  -HttpListener $httpListener `
  -RedirectConfiguration (New-AzApplicationGatewayRedirectConfiguration `
    -Name 'http-to-https' `
    -RedirectType 'Permanent' `
    -TargetListener $listener1 `
    -IncludePath $true `
    -IncludeQueryString $true)
```

## Advanced Routing Configurations

### Health Probes for Backend Monitoring

Define probes to detect unhealthy backends:

```powershell
# Custom probe for API backend
$probe = New-AzApplicationGatewayProbeConfig `
  -Name 'api-probe' `
  -Protocol 'Http' `
  -HostName 'api.example.com' `
  -Path '/health' `
  -Interval 30 `
  -Timeout 10 `
  -UnhealthyThreshold 3 `
  -PickHostNameFromBackendHttpSettings $true

# Associate probe with HTTP settings
$httpSettings = New-AzApplicationGatewayBackendHttpSettings `
  -Name 'api-settings' `
  -Port 80 `
  -Protocol 'Http' `
  -CookieBasedAffinity 'Disabled' `
  -Probe $probe `
  -RequestTimeout 30

# Backend health check
Get-AzApplicationGatewayBackendHealth `
  -ResourceGroupName 'prod-rg' `
  -ApplicationGatewayName 'app-gateway'
```

### Session Affinity (Sticky Sessions)

Ensure user requests route to same backend:

```powershell
# Enable cookie-based affinity
$httpSettings = New-AzApplicationGatewayBackendHttpSettings `
  -Name 'sticky-settings' `
  -Port 80 `
  -Protocol 'Http' `
  -CookieBasedAffinity 'Enabled' `
  -CookieName 'APPGWROUTE' `
  -RequestTimeout 30
```

### Request Rewriting

Rewrite headers and URL paths before sending to backend:

```powershell
# Add custom header indicating request came through gateway
$rewriteRuleSet = New-AzApplicationGatewayRewriteRuleSet `
  -Name 'add-headers'

$rule = New-AzApplicationGatewayRewriteRule `
  -Name 'add-x-forwarded' `
  -RuleSequence 100 `
  -ActionSet (New-AzApplicationGatewayRewriteRuleActionSet `
    -RequestHeaderConfiguration @(@{Header = 'X-Forwarded-For'; Value = '{var_client_ip}'}) `
    -ResponseHeaderConfiguration @(@{Header = 'X-Gateway-Version'; Value = 'v2'}))

# Path rewriting example: /old-path/* -> /new-path/*
$pathRewriteRule = New-AzApplicationGatewayRewriteRule `
  -Name 'rewrite-path' `
  -RuleSequence 200 `
  -Condition (New-AzApplicationGatewayRewriteRuleCondition `
    -Variable 'url_path' `
    -Pattern '^/old-path/(.*)$') `
  -ActionSet (New-AzApplicationGatewayRewriteRuleActionSet `
    -UrlConfiguration @{ModifiedPath = '/new-path/$1'})
```

## High Availability Configuration

### Multi-Region Failover

Deploy Application Gateway across multiple regions with Traffic Manager:

```powershell
# Traffic Manager profile routes between regions
$profile = New-AzTrafficManagerProfile `
  -Name 'app-global' `
  -ResourceGroupName 'prod-rg' `
  -ProfileStatus 'Enabled' `
  -TrafficRoutingMethod 'Geographic'

# Add endpoints for each region
Add-AzTrafficManagerEndpointConfig `
  -EndpointName 'east-us' `
  -EndpointStatus 'Enabled' `
  -EndpointType 'AzureEndpoints' `
  -ResourceId "/subscriptions/.../resourceGroups/prod-rg-east/providers/Microsoft.Network/applicationGateways/app-gateway-east" `
  -GeoMapping @('US', 'CA') `
  -TrafficManagerProfile $profile

# Geographic routing ensures users connect to nearest region
```

### Auto-Scaling Configuration

```powershell
# Auto-scale from 2 to 10 instances based on capacity units
$autoScaleConfig = New-AzApplicationGatewayAutoscaleConfiguration `
  -MinCapacity 2 `
  -MaxCapacity 10

# Monitor capacity units
Get-AzApplicationGatewayAutoscaleConfiguration `
  -ApplicationGateway $appGw | 
  Select-Object MinCapacity, MaxCapacity
```

## Security: Web Application Firewall (WAF)

### Enable WAF_v2 with OWASP Rules

```powershell
# Create WAF policy
$wafPolicy = New-AzWebApplicationFirewallPolicy `
  -Name 'app-gateway-waf' `
  -ResourceGroupName 'prod-rg' `
  -ManagedRules (New-AzWebApplicationFirewallPolicyManagedRuleSet `
    -ManagedRuleSetType 'OWASP' `
    -ManagedRuleSetVersion '3.2' `
    -Exclusion @( `
      New-AzWebApplicationFirewallPolicyManagedRuleExclusion `
        -MatchVariable 'RequestHeaderNames' `
        -SelectorMatchOperator 'Equals' `
        -Selector 'X-Forwarded-For'))

# Associate WAF policy with gateway
$appGw = Update-AzApplicationGateway `
  -ApplicationGateway $appGw `
  -WebApplicationFirewallPolicyId $wafPolicy.Id
```

## Monitoring and Diagnostics

### Application Insights Integration

```csharp
// Instrument backend application to correlate requests
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

public class ApiController : ControllerBase
{
    private readonly TelemetryClient _telemetry;
    
    public ApiController(TelemetryClient telemetry)
    {
        _telemetry = telemetry;
    }
    
    [HttpGet("/api/data")]
    public IActionResult GetData()
    {
        var requestProps = new Dictionary<string, string>
        {
            { "AppGW-RuleId", Request.Headers["X-AppGW-Rule"].ToString() },
            { "BackendPool", Request.Headers["X-Backend-Pool"].ToString() }
        };
        
        _telemetry.TrackEvent("APIRequest", requestProps);
        
        return Ok(new { message = "Success" });
    }
}
```

### Metrics and Alerts

```powershell
# Alert when backend health degrades
$condition = New-AzMetricAlertRuleV2Criteria `
  -MetricName 'HealthyHostCount' `
  -MetricNamespace 'Microsoft.Network/applicationGateways' `
  -Name 'HealthyHostCount' `
  -Operator 'LessThan' `
  -Threshold 1 `
  -TimeAggregation 'Average'

New-AzMetricAlertRuleV2 `
  -Name 'AppGW-UnhealthyBackend' `
  -ResourceGroupName 'prod-rg' `
  -TargetResourceId "/subscriptions/.../resourceGroups/prod-rg/providers/Microsoft.Network/applicationGateways/app-gateway" `
  -Criteria $condition `
  -ActionGroup $actionGroup.Id `
  -Frequency 00:05:00 `
  -WindowSize 00:10:00
```

## Base Coat Assets

- Agent: `agents/middleware-dev.agent.md`
- Skill: `skills/azure-compute/`
- Instruction: `instructions/routing-patterns.instructions.md`

## References

- [Application Gateway Documentation](https://docs.microsoft.com/azure/application-gateway/)
- [Path-Based Routing](https://docs.microsoft.com/azure/application-gateway/url-route-overview)
- [Multi-Site Hosting](https://docs.microsoft.com/azure/application-gateway/multiple-site-overview)
- [Web Application Firewall](https://docs.microsoft.com/azure/web-application-firewall/)
- [Application Gateway Monitoring](https://docs.microsoft.com/azure/application-gateway/application-gateway-diagnostics)
