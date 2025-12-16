"""Simple tests for Flask application."""

import os
import pytest
from unittest.mock import MagicMock, patch

# Set environment variables before importing main
os.environ["AWS_REGION"] = "us-east-1"
os.environ["DYNAMODB_TABLE_NAME"] = "test-table"

# Mock boto3 before importing main
with patch("boto3.resource") as mock_resource:
    mock_table = MagicMock()
    mock_table.table_name = "test-table"
    mock_resource.return_value.Table.return_value = mock_table
    from main import app


@pytest.fixture
def client():
    """Create test client for Flask app."""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


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
