
"""Secure document upload and retrieval for SentinelPay KYC submissions."""

import os
import uuid
from pathlib import PurePath

import boto3
from flask import (
    Blueprint,
    request,
    jsonify,
    current_app,
)

from app.auth import require_auth


documents_bp = Blueprint(
    "documents",
    __name__,
)

KYC_BUCKET = os.environ.get(
    "KYC_BUCKET",
    "sentinelpay-kyc-documents",
)

AWS_REGION = os.environ.get(
    "AWS_REGION",
    "af-south-1",
)

ALLOWED_EXTENSIONS = {
    ".pdf",
    ".jpg",
    ".jpeg",
    ".png",
}

MAX_DOCUMENT_SIZE = 10 * 1024 * 1024


def _s3():
    """
    Create an S3 client using Boto3's default credential provider chain.

    AWS ECS Fargate:
        Uses the task IAM role.

    Local development:
        Uses a configured AWS profile or other supported
        temporary credential provider.

    No AWS credentials are hardcoded or explicitly handled.
    """
    return boto3.client(
        "s3",
        region_name=AWS_REGION,
    )


def _validate_filename(filename):
    """Validate the uploaded document filename."""

    if not filename:
        return None

    # Normalize both Windows and Unix-style separators.
    filename = filename.replace("\\", "/").split("/")[-1]

    if filename in {".", "..", ""}:
        return None

    extension = os.path.splitext(filename)[1].lower()

    if extension not in ALLOWED_EXTENSIONS:
        return None

    return filename


@documents_bp.route(
    "/upload",
    methods=["POST"],
)
@require_auth
def upload_document():
    """
    Upload a private KYC document for the authenticated user.

    Security controls:
    - Authentication required
    - File extension validation
    - Maximum file size
    - Randomized S3 object key
    - No public-read ACL
    - User-specific S3 namespace
    """

    if "file" not in request.files:
        return jsonify({
            "error": "file required",
        }), 400

    uploaded_file = request.files["file"]

    filename = _validate_filename(
        uploaded_file.filename
    )

    if not filename:
        return jsonify({
            "error": "invalid file type or filename",
        }), 400

    user_id = str(
        request.current_user_id
    )

    # Prevent user identifiers from introducing path separators.
    if not user_id or "/" in user_id or "\\" in user_id:
        return jsonify({
            "error": "invalid user identifier",
        }), 400

    extension = os.path.splitext(filename)[1].lower()

    key = f"users/{user_id}/{uuid.uuid4().hex}{extension}"

    try:
        # Read no more than MAX_DOCUMENT_SIZE + 1 bytes.
        # This avoids loading arbitrarily large uploads into memory.
        document_data = uploaded_file.stream.read(
            MAX_DOCUMENT_SIZE + 1
        )

        if len(document_data) > MAX_DOCUMENT_SIZE:
            return jsonify({
                "error": "file exceeds maximum size of 10 MB",
            }), 413

        if not document_data:
            return jsonify({
                "error": "empty file",
            }), 400

        _s3().put_object(
            Bucket=KYC_BUCKET,
            Key=key,
            Body=document_data,
            ContentType=(
                uploaded_file.mimetype
                or "application/octet-stream"
            ),
        )

        return jsonify({
            "key": key,
            "bucket": KYC_BUCKET,
        }), 201

    except Exception:
        current_app.logger.exception(
            "KYC document upload failed"
        )

        return jsonify({
            "error": "document operation failed",
        }), 500


@documents_bp.route(
    "/<path:key>",
    methods=["GET"],
)
@require_auth
def get_document(key):
    """
    Retrieve a document belonging to the authenticated user.

    The S3 object key must match the current user's namespace.
    """

    user_id = str(
        request.current_user_id
    )

    if not user_id or "/" in user_id or "\\" in user_id:
        return jsonify({
            "error": "invalid user identifier",
        }), 400

    expected_prefix = f"users/{user_id}/"

    if not key.startswith(expected_prefix):
        return jsonify({
            "error": "unauthorized access to document",
        }), 403

    try:
        obj = _s3().get_object(
            Bucket=KYC_BUCKET,
            Key=key,
        )

        return (
            obj["Body"].read(),
            200,
            {
                "Content-Type": obj.get(
                    "ContentType",
                    "application/octet-stream",
                ),
                "X-Content-Type-Options": "nosniff",
                "Content-Disposition": "attachment",
            },
        )

    except Exception:
        current_app.logger.exception(
            "KYC document retrieval failed",
            extra={
                "user_id": user_id,
                "key": key,
            },
        )

        return jsonify({
            "error": "document retrieval failed",
        }), 404
