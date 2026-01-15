"""Unit tests for the main application."""

import os
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.config import Settings


@pytest.fixture
def client():
    """Create a test client for the FastAPI application."""
    return TestClient(app)


@pytest.fixture
def mock_settings(monkeypatch):
    """Mock settings with a test name."""
    monkeypatch.setenv("NOMBRE", "TestUser")
    # Reload settings to pick up the new environment variable
    from app import config
    config.settings = Settings()
    return config.settings


def test_root_endpoint(client, mock_settings):
    """Test the root endpoint returns a greeting."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "TestUser" in data["message"]
    assert "¡Hola" in data["message"]


def test_root_endpoint_default_name(client, monkeypatch):
    """Test the root endpoint with default name when NOMBRE is not set."""
    # Remove NOMBRE if it exists
    monkeypatch.delenv("NOMBRE", raising=False)
    from app import config
    config.settings = Settings()
    
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert "Usuario" in data["message"] or "Bienvenido" in data["message"]


def test_health_check_endpoint(client):
    """Test the health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "python-microservice"


def test_settings_get_nombre(mock_settings):
    """Test Settings.get_nombre() method."""
    nombre = mock_settings.get_nombre()
    assert nombre == "TestUser"


def test_settings_default_nombre(monkeypatch):
    """Test Settings with default nombre when NOMBRE is not set."""
    monkeypatch.delenv("NOMBRE", raising=False)
    settings = Settings()
    assert settings.get_nombre() == "Usuario"
