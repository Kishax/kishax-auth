# Kishax Authentication Service

## Overview

This service implements a complete authentication flow using multiple identity providers → Keycloak → AWS IAM Identity Center → AWS Console. It provides a seamless single sign-on (SSO) experience for users to access AWS resources through their GitHub accounts or email/password credentials.

## Architecture

```
┌─────────────┐    ┌──────────────┐    ┌────────────────────────┐    ┌─────────────┐
│  GitHub     │    │   Keycloak   │    │  AWS IAM Identity      │    │ AWS Console │
│  OAuth      │◄──►│   Identity   │◄──►│  Center (SAML)         │◄──►│ & Services  │
└─────────────┘    │   Provider   │    │                        │    │             │
┌─────────────┐    │              │    │                        │    │             │
│Email/Pass   │◄──►│ (kishax      │    │                        │    │             │
│Local Auth   │    │  realm)      │    │                        │    │             │
└─────────────┘    └──────────────┘    └────────────────────────┘    └─────────────┘
       │                   │                       │                        │
       │                   │                       │                        │
       ▼                   ▼                       ▼                        ▼
Authentication      Identity Federation      SAML Integration        Service Access
 (2FA Required)
```

## Authentication Flow

### 1. User Authentication Journey

#### Option 1: GitHub OAuth Flow
1. **User Access**: User attempts to access AWS Console via IAM Identity Center
2. **SAML Redirect**: IAM Identity Center redirects to Keycloak SAML endpoint
3. **Identity Provider Selection**: User selects GitHub OAuth authentication
4. **GitHub OAuth**: User authenticates with GitHub OAuth
5. **2FA Verification**: User completes required two-factor authentication (TOTP/Authenticator)
6. **Attribute Mapping**: Keycloak maps GitHub user attributes to SAML assertions
7. **SAML Response**: Keycloak sends SAML response back to IAM Identity Center
8. **AWS Access**: IAM Identity Center grants access to AWS Console and services

#### Option 2: Email/Password Flow
1. **User Access**: User attempts to access AWS Console via IAM Identity Center
2. **SAML Redirect**: IAM Identity Center redirects to Keycloak SAML endpoint
3. **Local Authentication**: User enters email/password credentials
4. **2FA Verification**: User completes required two-factor authentication (TOTP/Authenticator)
5. **Group Assignment**: User automatically assigned to `kishax-dev` group with `developer` role
6. **SAML Response**: Keycloak sends SAML response back to IAM Identity Center
7. **AWS Access**: IAM Identity Center grants access to AWS Console and services

### 2. Key Components

#### Authentication Options

##### GitHub Identity Provider
- **Purpose**: External OAuth authentication source
- **Mapping Strategy**: Uses GitHub's permanent user ID (not username/email)
- **Attributes Collected**:
  - `id` → `username` (permanent identifier)
  - `login` → `github_username` (display name)
  - `email` → `email`
  - `name` → `firstName`

##### Local Email/Password Authentication
- **Purpose**: Direct authentication with Keycloak user store
- **Security Features**:
  - Email verification required
  - Strong password policy enforcement
  - Brute force protection
  - Mandatory 2FA (TOTP/Authenticator apps)
- **Default Group Assignment**: All new users automatically join `kishax-dev` group
- **Default Permissions**: `developer` role with standard development access

#### Keycloak (Identity Provider)
- **Realm**: `kishax`
- **Protocol**: SAML 2.0 for IAM Identity Center integration
- **Features**:
  - Multiple authentication methods (GitHub OAuth + Local)
  - Mandatory 2FA for all authentication methods
  - SAML assertion generation
  - User attribute mapping
  - Session management
  - Group-based access control

#### AWS IAM Identity Center
- **Integration**: SAML-based federation
- **User Provisioning**: Automatic via SAML assertions
- **Access Control**: Permission sets and group assignments

## File Structure

```
apps/kishax-auth/
├── README.md                           # This documentation
├── Dockerfile                          # Container configuration
├── realm-export.json.template          # Keycloak realm configuration template
├── docker-compose.yml                  # Local development setup
└── scripts/
    └── start-with-template.sh          # Environment variable substitution script
```

## Configuration Files

### realm-export.json.template

This is the main configuration file that defines:

- **Realm Settings**: Basic realm configuration for `kishax`
- **GitHub Identity Provider**: OAuth client configuration and user attribute mapping
- **IAM Identity Center Client**: SAML client configuration with proper endpoints
- **Protocol Mappers**: SAML attribute mapping for AWS integration
- **Client Scopes**: OpenID Connect scopes for profile and email

Key configuration sections:

```json
{
  "identityProviders": [{
    "alias": "github",
    "config": {
      "clientId": "${GITHUB_CLIENT_ID}",
      "clientSecret": "${GITHUB_CLIENT_SECRET}"
    }
  }],
  "clients": [{
    "clientId": "${IAM_IDENTITY_CENTER_ISSUER_URL}",
    "protocol": "saml",
    "redirectUris": ["${IAM_IDENTITY_CENTER_ACS_URL}"]
  }]
}
```

### Environment Variables

The following environment variables are substituted during container startup:

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_CLIENT_ID` | GitHub OAuth application client ID | `abc123...` |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth application client secret | `secret123...` |
| `IAM_IDENTITY_CENTER_ISSUER_URL` | AWS IAM Identity Center issuer URL | `https://ap-northeast-3.signin.aws.amazon.com/platform/saml/d-xxxxx` |
| `IAM_IDENTITY_CENTER_ACS_URL` | AWS IAM Identity Center ACS URL | `https://ap-northeast-3.signin.aws.amazon.com/platform/saml/acs/xxxxx` |

## Docker Configuration

### Multi-stage Build

The Dockerfile uses Keycloak 25.0.6 with:
- PostgreSQL database support
- Token exchange and fine-grained authorization features
- Health and metrics endpoints enabled
- Edge proxy configuration for AWS ALB integration

### Key Environment Variables

```dockerfile
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_HTTP_ENABLED=true
ENV KC_HOSTNAME_STRICT=false
ENV KC_HOSTNAME_STRICT_HTTPS=false
ENV KC_PROXY=edge
```

## Development Setup

### Local Testing with Docker Compose

```bash
# Build and start services
docker-compose up --build

# Access Keycloak admin console
# URL: http://localhost:3000/admin/
# Default: admin / admin

# Access kishax realm
# URL: http://localhost:3000/realms/kishax/account
```

### Database

- **Engine**: PostgreSQL 15 Alpine
- **Port**: 5432 (internal), 5433 (local port forwarding)
- **Schema**: Automatically initialized by Keycloak

## Production Deployment

### AWS ECS Integration

The service is deployed on AWS ECS Fargate with:
- Application Load Balancer (ALB) integration
- SSL termination at ALB level
- Health checks on `/health` endpoint
- Auto-scaling based on CPU and memory utilization

### Security Configurations

- **SSL/TLS**: Required for external connections (ALB terminates SSL)
- **SAML Assertions**: Signed with RSA SHA256
- **Session Security**: Brute force protection enabled
- **Password Policy**: Strong password requirements for admin accounts

## SAML Configuration Details

### Protocol Mappers

The following SAML attributes are mapped for IAM Identity Center:

| SAML Attribute | Keycloak User Attribute | Purpose |
|---------------|------------------------|---------|
| `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` | `username` | Primary user identifier |
| `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` | `email` | User email address |
| `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname` | `firstName` | User first name |
| `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname` | `lastName` | User last name |

### GitHub Attribute Mapping Strategy

**Problem**: GitHub usernames and emails can change, causing user account fragmentation in AWS.

**Solution**: Use GitHub's permanent numeric `id` field as the primary identifier:

```json
{
  "name": "github-id-mapper",
  "identityProviderMapper": "github-user-attribute-mapper",
  "config": {
    "jsonField": "id",
    "userAttribute": "username"
  }
}
```

This ensures user continuity even when GitHub usernames or emails change.

## Troubleshooting

### Common Issues

1. **SAML Invalid Request Error**
   - **Cause**: Client ID mismatch between Keycloak and IAM Identity Center
   - **Solution**: Ensure `clientId` in realm config matches IAM Identity Center issuer URL

2. **User Attributes Not Mapping**
   - **Cause**: Incorrect protocol mapper configuration
   - **Solution**: Verify SAML attribute names match IAM Identity Center expectations

3. **Health Check Failures**
   - **Cause**: Database connection issues or Keycloak startup problems
   - **Solution**: Check database connectivity and container logs

4. **GitHub OAuth Issues**
   - **Cause**: Invalid client credentials or redirect URI mismatch
   - **Solution**: Verify GitHub OAuth app configuration and callback URLs

### Debugging Commands

```bash
# Check container status
docker ps

# View Keycloak logs
docker logs kishax-keycloak

# Test SAML metadata endpoint
curl https://auth.kishax.net/realms/kishax/protocol/saml/descriptor

# Test health endpoint
curl http://localhost:3000/health

# Port forward to database for debugging
kubectl port-forward service/postgres 5433:5432
```

## Monitoring and Maintenance

### Health Endpoints

- **Health Check**: `/health` - Container health status
- **Metrics**: `/metrics` - Prometheus-compatible metrics
- **Admin Console**: `/admin/` - Administrative interface

### Regular Maintenance

1. **Certificate Renewal**: Monitor SAML signing certificate expiration
2. **Database Backups**: Regular PostgreSQL backups recommended
3. **Security Updates**: Keep Keycloak version updated
4. **Log Monitoring**: Monitor authentication failures and errors

## Security Considerations

### Best Practices Implemented

1. **Permanent User Identification**: Using GitHub ID prevents account fragmentation
2. **SAML Assertion Signing**: All assertions are cryptographically signed
3. **Session Management**: Configurable session timeouts and security policies
4. **Brute Force Protection**: Automatic account lockout after failed attempts
5. **Secure Transport**: HTTPS required for all external communications

### Access Control

- Admin access restricted to authorized personnel only
- GitHub OAuth scopes limited to necessary user information
- SAML assertions contain minimal required user attributes
- Database access restricted to application layer only

## Support and Maintenance

For issues or questions regarding this authentication service:

1. Check container logs for error messages
2. Verify all environment variables are properly configured
3. Test individual components (GitHub OAuth, Keycloak, IAM Identity Center)
4. Consult Keycloak and AWS IAM Identity Center documentation for advanced configuration

## 現在手動でやっていること
- Clients\>account-console\>Client Scopesにemail, offline\_access, profile, rolesを追加する
こちらおそらく初期セットアップの時にDBに入れておけば良い気がする
- DBのバックアップ
