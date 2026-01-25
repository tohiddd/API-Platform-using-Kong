"""
Authentication module for JWT token management.

This module handles:
- JWT token generation
- JWT token verification and decoding
- Token payload creation with claims

Key Concept: JWT Structure
--------------------------
A JWT consists of three parts separated by dots:
1. Header: {"alg": "HS256", "typ": "JWT"}
2. Payload: {"sub": "user_id", "exp": timestamp, "iat": timestamp, ...}
3. Signature: HMACSHA256(base64UrlEncode(header) + "." + base64UrlEncode(payload), secret)

Key Concept: JWT Claims
-----------------------
- sub (subject): The principal that is the subject of the JWT (usually user ID)
- exp (expiration): Expiration time (Unix timestamp)
- iat (issued at): Time the token was issued
- iss (issuer): Who created and signed the token
- Custom claims: Any additional data (username, email, etc.)

Key Concept: Kong JWT Plugin Integration
----------------------------------------
Kong's JWT plugin validates tokens at the gateway level.
It checks:
1. Token signature using the configured secret
2. Token expiration
3. Required claims

This provides a security layer BEFORE requests reach your microservice.
"""

import jwt
from datetime import datetime, timezone
from functools import wraps
from flask import request, jsonify
from .config import Config


def create_jwt_token(user_id: int, username: str) -> str:
    """
    Create a JWT token for an authenticated user.
    
    Args:
        user_id: The user's database ID
        username: The user's username
        
    Returns:
        Encoded JWT token string
    
    Token Payload includes:
    - sub: User ID (standard claim for subject)
    - username: For convenience in identifying user
    - iat: Issued at timestamp
    - exp: Expiration timestamp
    - iss: Token issuer identifier
    """
    now = datetime.now(timezone.utc)
    expiration = now + Config.get_jwt_expiration()
    
    payload = {
        'sub': str(user_id),           # Subject (user identifier)
        'username': username,           # Custom claim for username
        'iat': now,                     # Issued at
        'exp': expiration,              # Expiration time
        'iss': 'user-service'           # Issuer (this service)
    }
    
    token = jwt.encode(
        payload,
        Config.JWT_SECRET_KEY,
        algorithm=Config.JWT_ALGORITHM
    )
    
    return token


def decode_jwt_token(token: str) -> dict:
    """
    Decode and validate a JWT token.
    
    Args:
        token: The JWT token string
        
    Returns:
        Decoded payload dict
        
    Raises:
        jwt.ExpiredSignatureError: If token has expired
        jwt.InvalidTokenError: If token is invalid
    """
    payload = jwt.decode(
        token,
        Config.JWT_SECRET_KEY,
        algorithms=[Config.JWT_ALGORITHM],
        options={'require': ['exp', 'iat', 'sub']}
    )
    return payload


def verify_jwt_token(token: str) -> tuple:
    """
    Verify a JWT token and return status.
    
    Args:
        token: The JWT token string
        
    Returns:
        Tuple of (is_valid: bool, payload_or_error: dict/str)
    """
    try:
        payload = decode_jwt_token(token)
        return True, payload
    except jwt.ExpiredSignatureError:
        return False, 'Token has expired'
    except jwt.InvalidTokenError as e:
        return False, f'Invalid token: {str(e)}'


def jwt_required(f):
    """
    Decorator for protecting routes with JWT authentication.
    
    This provides application-level JWT verification.
    Note: Kong also validates JWT at gateway level (defense in depth).
    
    Usage:
        @app.route('/protected')
        @jwt_required
        def protected_route():
            # Access current_user from request
            user = request.current_user
            return jsonify(user)
    
    The decorator:
    1. Extracts token from Authorization header
    2. Validates the token
    3. Attaches user info to request object
    4. Returns 401 if authentication fails
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        # Extract Authorization header
        auth_header = request.headers.get('Authorization', '')
        
        if not auth_header:
            return jsonify({'error': 'Authorization header required'}), 401
        
        # Expected format: "Bearer <token>"
        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return jsonify({'error': 'Invalid authorization format. Use: Bearer <token>'}), 401
        
        token = parts[1]
        
        # Verify the token
        is_valid, result = verify_jwt_token(token)
        
        if not is_valid:
            return jsonify({'error': result}), 401
        
        # Attach user info to request for use in the route
        request.current_user = result
        
        return f(*args, **kwargs)
    
    return decorated

