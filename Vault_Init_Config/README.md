# Vault Groups Initialization Script

Este directorio contiene un script de PowerShell para inicializar grupos, políticas y autenticación en HashiCorp Vault.

## Archivos

- `Initialize-VaultGroups.ps1`: Script principal de inicialización
- `admin-policy.hcl`: Política con acceso completo (100% de funciones)
- `security-admin-policy.hcl`: Política para administración de autenticación y tokens
- `operation-policy.hcl`: Política para gestión total de secretos KV v2
- `developer-policy.hcl`: Política para listar secretos KV v2 (sin leer)

## Requisitos Previos

1. **Vault CLI**: El comando `vault` debe estar disponible en el PATH
2. **Variables de Ambiente**:
   - `VAULT_ADDR`: Dirección del servidor Vault (ej: `http://localhost:8200`)
   - `VAULT_TOKEN`: Token de autenticación con permisos suficientes

## Grupos Creados

El script crea los siguientes grupos:

1. **Admin**: Acceso completo a todas las funcionalidades de Vault
2. **Security Admin**: Administración de mecanismos de autenticación, tiempo de vida de tokens
3. **Operation**: Gestión total de secretos KV v2
4. **Developer**: Solo puede listar secretos KV v2 (sin leerlos)

## Características

### Idempotencia

El script es completamente idempotente:
- Verifica si las políticas ya existen antes de crearlas
- Compara el contenido de políticas existentes con las esperadas
- Verifica si los grupos ya existen y tienen las políticas correctas
- Si algo ya existe y coincide, lo omite
- Si algo existe pero no coincide, muestra una advertencia y lo omite

### Autenticación GitHub

El script habilita y configura la autenticación GitHub:
- Habilita el método de autenticación `github/`
- Solicita interactivamente el nombre de la organización de GitHub
- Crea un role que asigna la política `developer-policy` a usuarios autenticados vía GitHub

### Response Wrapping

- Configura el TTL máximo de Response Wrapping a 1 hora (3600 segundos)
- Todas las políticas incluyen acceso a `sys/wrapping/*` y `cubbyhole/*`
- Todos los grupos pueden usar Response Wrapping con duración máxima de 1 hora

## Uso

### Ejecución Básica

```powershell
./Initialize-VaultGroups.ps1
```

### Omitir Configuración de GitHub

```powershell
./Initialize-VaultGroups.ps1 -SkipGitHubAuth
```

## Ejemplo de Salida

```
========================================
  Inicialización de Vault Groups
========================================

[INFO] Verificando conexión con Vault...
[OK] Conexión con Vault establecida correctamente

=== Creando Políticas ===

[INFO] Verificando política: admin-policy
[OK] Política 'admin-policy' creada exitosamente

...

=== Creando Grupos ===

[INFO] Verificando grupo: Admin
[OK] Grupo 'Admin' creado exitosamente con políticas: admin-policy

...

=== Configurando GitHub Authentication ===

[INFO] Configurando autenticación GitHub...
Ingrese el nombre de la organización de GitHub: mi-org
[OK] Organización GitHub configurada: mi-org
[OK] Role 'github-developer-role' creado exitosamente con política 'developer-policy'

=== Configurando Response Wrapping ===

[INFO] Configurando Response Wrapping...
[OK] Response Wrapping configurado con TTL máximo de 1 hora
[OK] Todos los grupos tienen acceso a Response Wrapping a través de sus políticas

========================================
  Resumen de la Inicialización
========================================

Políticas:
  [OK] admin-policy
  [OK] security-admin-policy
  [OK] operation-policy
  [OK] developer-policy

Grupos:
  [OK] Admin
  [OK] Security Admin
  [OK] Operation
  [OK] Developer

[OK] Inicialización completada
```

## Notas Importantes

1. **Permisos del Token**: El token usado (`VAULT_TOKEN`) debe tener permisos suficientes para:
   - Crear políticas (`sys/policies/acl/*`)
   - Crear grupos (`identity/group/*`)
   - Habilitar métodos de autenticación (`auth/*`)
   - Configurar Response Wrapping (`sys/config/wrapping`)

2. **Nombres con Espacios**: Los grupos con espacios en el nombre (como "Security Admin") son manejados correctamente por el script.

3. **Ejecuciones Múltiples**: Puede ejecutar el script múltiples veces de forma segura. Solo creará o actualizará lo que no existe o no coincide.

4. **GitHub Authentication**: Si omite la configuración de GitHub con `-SkipGitHubAuth`, puede configurarla manualmente después usando:
   ```bash
   vault auth enable github
   vault write auth/github/config organization=<nombre-org>
   vault write auth/github/role/<nombre-role> policies=developer-policy
   ```
