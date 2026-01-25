"""
Configuration module for the User Service.

This module handles all configuration settings including:
- JWT secret key management (externalized via environment variables)
- Database configuration
- Token expiration settings

Key Concept: JWT (JSON Web Token)
---------------------------------
JWT is a compact, URL-safe means of representing claims between two parties.
Structure: header.payload.signature
- Header: Algorithm and token type
- Payload: Claims (user data, expiration, etc.)
- Signature: Verification using secret key

The secret is externalized (not hardcoded) for security best practices.
"""

import os
from datetime import timedelta


class Config:
    """Application configuration class."""
    
    # JWT Configuration
    # IMPORTANT: In production, this MUST be set via environment variable
    # Never commit actual secrets to version control
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'dev-secret-change-in-production')
    JWT_ALGORITHM = 'HS256'
    JWT_EXPIRATION_HOURS = int(os.environ.get('JWT_EXPIRATION_HOURS', '24'))
    
    # Database Configuration
    # SQLite database file path - persisted in container volume
    DATABASE_PATH = os.environ.get('DATABASE_PATH', '/app/data/users.db')
    
    # Application Settings
    DEBUG = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'
    HOST = os.environ.get('FLASK_HOST', '0.0.0.0')
    PORT = int(os.environ.get('FLASK_PORT', '5000'))
    
    @classmethod
    def get_jwt_expiration(cls):
        """Get JWT expiration as timedelta."""
        return timedelta(hours=cls.JWT_EXPIRATION_HOURS)

