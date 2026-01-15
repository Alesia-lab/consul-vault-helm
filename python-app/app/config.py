"""Configuration module for the application."""

import os
from typing import Optional


class Settings:
    """Application settings loaded from environment variables."""

    def __init__(self):
        """Initialize settings from environment variables."""
        self.nombre: str = os.getenv("NOMBRE", "Usuario")
        self.app_name: str = os.getenv("APP_NAME", "Python Microservice")
        self.version: str = os.getenv("APP_VERSION", "1.0.0")
        self.debug: bool = os.getenv("DEBUG", "false").lower() == "true"

    def get_nombre(self) -> str:
        """Get the name from environment variable."""
        return self.nombre


# Global settings instance
settings = Settings()
