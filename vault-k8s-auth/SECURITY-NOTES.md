# Notas de Seguridad - Configuración de Vault

## ⚠️ ADVERTENCIAS IMPORTANTES

Este proyecto soporta diferentes configuraciones de conectividad a Vault para facilitar el desarrollo y testing, pero **debes entender los riesgos de seguridad**:

### 1. Certificados Autofirmados (`skip_tls_verify = true`)

**Cuándo usar**: Desarrollo, testing, o cuando Vault usa certificados autofirmados.

**Riesgos**:
- Vulnerable a ataques Man-in-the-Middle (MITM)
- No hay validación de la identidad del servidor
- Los datos pueden ser interceptados

**Recomendación**: 
- Solo para desarrollo/testing
- En producción, usar certificados válidos o proporcionar `vault_ca_cert_file`

### 2. HTTP sin TLS (`http://` en `vault_address`)

**Cuándo usar**: Solo para desarrollo local o testing en entornos aislados.

**Riesgos**:
- **TODOS los datos se transmiten en texto plano**
- Vulnerable a interceptación de tráfico
- Tokens y secretos expuestos en la red

**Recomendación**:
- **NUNCA usar en producción**
- Solo para desarrollo local en localhost
- Usar siempre `https://` en cualquier entorno que no sea completamente aislado

### 3. Configuración Segura para Producción

```hcl
# ✅ CORRECTO para producción
vault_address        = "https://vault.example.com:8200"
vault_skip_tls_verify = false
vault_ca_cert_file   = "/path/to/valid-ca-cert.pem"  # Certificado CA válido
```

### 4. Configuración para Desarrollo/Testing

```hcl
# ⚠️ Solo para desarrollo/testing
vault_address        = "https://vault-dev.example.com:8200"
vault_skip_tls_verify = true  # Para certificados autofirmados
# O
vault_address        = "http://localhost:8200"  # Solo localhost, nunca en red
```

## Checklist de Seguridad

Antes de desplegar a producción:

- [ ] `vault_address` usa `https://` (nunca `http://`)
- [ ] `vault_skip_tls_verify = false` (o `true` solo si es absolutamente necesario)
- [ ] `vault_ca_cert_file` configurado con certificado CA válido (si aplica)
- [ ] Conectividad segura a Vault (VPN, PrivateLink, etc.)
- [ ] Token de Vault usando método seguro (AppRole, AWS Auth, etc.)

## Troubleshooting

### Error: "certificate is valid for *.example.com, not vault.example.com"

**Solución 1** (Desarrollo/Testing):
```hcl
vault_skip_tls_verify = true
```

**Solución 2** (Producción):
- Usar el hostname correcto que coincide con el certificado
- O proporcionar el certificado CA correcto en `vault_ca_cert_file`

### Error: "tls: failed to verify certificate"

**Solución**:
- Para desarrollo: `vault_skip_tls_verify = true`
- Para producción: Verificar que el certificado es válido y proporcionar `vault_ca_cert_file` si es necesario
