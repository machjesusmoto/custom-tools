# Security Policy

## Development Security Requirements

### Pre-Commit Security Audit

Before any commit/push activity, all code MUST be audited to ensure:

1. **Adherence to security best practices**
   - No hardcoded credentials or secrets
   - Secure file permissions where applicable
   - Proper input validation and sanitization
   - Safe handling of sensitive data

2. **Prevention of unintended exposure**
   - Scripts should not create world-readable files containing sensitive data
   - Temporary files should be securely deleted
   - Output locations should be clearly documented

3. **Risk disclosure**
   - If a tool inherently handles sensitive data, it MUST:
     - Warn users before execution
     - Document what sensitive data is involved
     - Provide clear guidance on secure usage
     - Offer secure alternatives where possible

## Security Principles for This Repository

### Backup Scripts
- Always provide both convenience and secure versions
- Default to secure permissions (600) for output files
- Warn about sensitive data inclusion
- Document secure storage and deletion practices

### General Scripts
- Never store credentials in scripts
- Use environment variables or secure prompts for secrets
- Document any security implications in README
- Provide secure usage examples

## Reporting Security Issues

If you discover a security vulnerability in any of these tools:
1. Do NOT open a public issue
2. Contact the repository owner directly
3. Provide details about the vulnerability
4. Suggest fixes if possible

## Security Checklist for Contributors

Before submitting code:
- [ ] No hardcoded credentials
- [ ] Secure file permissions implemented
- [ ] Sensitive data handling documented
- [ ] Security warnings added where needed
- [ ] Secure deletion practices documented
- [ ] README updated with security notes