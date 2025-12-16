"""Simple tests for Flask application."""

import os
import sys
import pytest
from unittest.mock import MagicMock, patch

# Set environment variables before importing main
os.environ["AWS_REGION"] = "us-east-1"
os.environ["DYNAMODB_TABLE_NAME"] = "test-table"

# Add current directory to path so we can import main
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


@pytest.fixture(scope="module")
def app():
    """Create and configure app instance for testing."""
    with patch("boto3.resource") as mock_resource:
        mock_table = MagicMock()
        mock_table.table_name = "test-table"
        mock_resource.return_value.Table.return_value = mock_table

        # Import main module within the patch context
        import main

        main.app.config["TESTING"] = True
        yield main.app


@pytest.fixture
def client(app):
    """Create test client for Flask app."""
    return app.test_client()


def test_health_check(client):
    """Test health check endpoint returns healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    json_data = response.get_json()
    assert json_data["status"] == "healthy"
    assert json_data["service"] == "picus-api"


def test_health_check_method(client):
    """Test health check endpoint only accepts GET requests."""
    response = client.post("/health")
    assert response.status_code == 405


def test_404_error(client):
    """Test 404 error handler."""
    response = client.get("/nonexistent")
    assert response.status_code == 404
    json_data = response.get_json()
    assert "error" in json_data
    assert json_data["error"] == "Not found"
