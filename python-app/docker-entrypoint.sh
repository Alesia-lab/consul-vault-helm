#!/bin/sh
set -e

# Cargar variables de entorno desde Vault si existen
if [ -f /vault/secrets/NOMBRE ]; then
    . /vault/secrets/NOMBRE
fi

# Ejecutar la aplicación
exec "$@"
