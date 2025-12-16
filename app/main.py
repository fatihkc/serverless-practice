"""Flask application for Picus SRE Case Study."""

import logging
import uuid
import os
from flask import Flask, jsonify, request
from botocore.exceptions import ClientError
import boto3

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Initialize DynamoDB client
dynamodb = boto3.resource("dynamodb", region_name=os.environ.get("AWS_REGION", "us-east-1"))
table = dynamodb.Table(os.environ.get("DYNAMODB_TABLE_NAME", "picus-data"))

logger.info(f"DynamoDB client initialized for table: {table.table_name}")


@app.route("/health", methods=["GET"])
def health_check():
    """
    Health check endpoint for ALB health checks.

    Returns:
        JSON: Status of the service
    """
    return jsonify({"status": "healthy", "service": "picus-api"})


@app.route("/picus/list", methods=["GET"])
def list_items():
    """
    List all items from DynamoDB table.

    Returns:
        JSON: List of all items in the database
    """
    try:
        response = table.scan()
        items = response.get("Items", [])

        # Handle pagination
        while "LastEvaluatedKey" in response:
            response = table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
            items.extend(response.get("Items", []))

        logger.info(f"Retrieved {len(items)} items")

        return jsonify(items), 200

    except ClientError as e:
        logger.error(f"Error listing items: {e.response['Error']['Message']}")
        return jsonify({"error": "Failed to retrieve items from database"}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@app.route("/picus/put", methods=["POST"])
def put_item():
    """
    Create a new item in DynamoDB table.

    Returns:
        JSON: Generated UUID for the created item
    """
    try:
        # Get JSON data from request
        data = request.get_json()

        if not data:
            return jsonify({"error": "No data provided"}), 400

        # Generate UUID for the item
        item_id = str(uuid.uuid4())

        # Store in DynamoDB
        table.put_item(Item={"id": item_id, "data": data})

        logger.info(f"Created item with id: {item_id}")

        return jsonify({"id": item_id}), 201

    except ClientError as e:
        logger.error(f"Error creating item: {e.response['Error']['Message']}")
        return jsonify({"error": "Failed to create item in database"}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@app.route("/picus/get/<key>", methods=["GET"])
def get_item(key):
    """
    Retrieve a specific item from DynamoDB by ID.

    Args:
        key: Unique identifier of the item

    Returns:
        JSON: Item data with ID
    """
    try:
        response = table.get_item(Key={"id": key})
        item = response.get("Item")

        if not item:
            logger.warning(f"Item not found with id: {key}")
            return jsonify({"error": f"Item with id '{key}' not found"}), 404

        logger.info(f"Retrieved item with id: {key}")

        return jsonify(item), 200

    except ClientError as e:
        logger.error(f"Error retrieving item {key}: {e.response['Error']['Message']}")
        return jsonify({"error": "Failed to retrieve item from database"}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors."""
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    # For local development only
    app.run(host="0.0.0.0", port=8000, debug=False)
