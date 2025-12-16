"""Lambda function for DELETE /picus/{key} endpoint."""

import json
import logging
import os
from typing import Any, Dict
import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource("dynamodb")
table_name = os.environ.get("DYNAMODB_TABLE_NAME", "picus-data")
table = dynamodb.Table(table_name)


def delete_item(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for DELETE operation on DynamoDB item.

    Args:
        event: Lambda event containing path parameters
        context: Lambda context object

    Returns:
        Dictionary with statusCode and response body

    Expected ALB event structure:
    {
        "path": "/picus/123e4567-e89b-12d3-a456-426614174000",
        "httpMethod": "DELETE",
        "pathParameters": {"key": "123e4567-e89b-12d3-a456-426614174000"},
        ...
    }
    """
    logger.info(f"Received DELETE request: {json.dumps(event)}")

    try:
        # Extract key from path or pathParameters
        key = None

        # Try to get from pathParameters (API Gateway style)
        if "pathParameters" in event and event["pathParameters"]:
            key = event["pathParameters"].get("key")

        # If not found, try to extract from path
        if not key and "path" in event:
            path = event["path"]
            # Extract key from path like /picus/{key}
            parts = path.strip("/").split("/")
            if len(parts) >= 2:
                key = parts[1]

        # For ALB, the path might be in rawPath or path
        if not key and "rawPath" in event:
            path = event["rawPath"]
            parts = path.strip("/").split("/")
            if len(parts) >= 2:
                key = parts[1]

        if not key:
            logger.error("Key not found in request")
            return {
                "statusCode": 400,
                "statusDescription": "400 Bad Request",
                "headers": {
                    "Content-Type": "application/json"
                },
                "body": json.dumps({
                    "detail": "Missing item key in path"
                })
            }

        logger.info(f"Attempting to delete item with key: {key}")

        # Check if item exists before deleting
        response = table.get_item(Key={"id": key})

        if "Item" not in response:
            logger.warning(f"Item not found with key: {key}")
            return {
                "statusCode": 404,
                "statusDescription": "404 Not Found",
                "headers": {
                    "Content-Type": "application/json"
                },
                "body": json.dumps({
                    "detail": f"Item with id '{key}' not found"
                })
            }

        # Delete the item
        table.delete_item(Key={"id": key})

        logger.info(f"Successfully deleted item with key: {key}")

        return {
            "statusCode": 200,
            "statusDescription": "200 OK",
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "message": f"Item '{key}' deleted successfully"
            })
        }

    except ClientError as e:
        logger.error(f"DynamoDB error: {e.response['Error']['Message']}")
        return {
            "statusCode": 500,
            "statusDescription": "500 Internal Server Error",
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "detail": "Failed to delete item from database"
            })
        }

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return {
            "statusCode": 500,
            "statusDescription": "500 Internal Server Error",
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "detail": "Internal server error"
            })
        }
