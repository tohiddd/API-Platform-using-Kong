"""
API Routes for the User Service.

This module defines all API endpoints:

Authentication APIs:
- POST /login: Authenticate user, return JWT
- GET /verify: Verify JWT token validity

User APIs:
- GET /users: List all users (JWT required)

Public APIs (Authentication Bypass):
- GET /health: Health check endpoint
- GET /verify: Token verification (also public)

Key Concept: Authentication Bypass in Kong
------------------------------------------
Kong can be configured to skip JWT validation for specific routes.
This is done by:
1. Not applying the JWT plugin to those routes, OR
2. Using the 'skip' configuration in route matching

Routes like /health are essential for:
- Kubernetes liveness/readiness probes
- Load balancer health checks
- Monitoring systems

These must NOT require authentication.
"""

from flask import Blueprint, request, jsonify
from .database import get_user_by_username, get_all_users, verify_password
from .auth import create_jwt_token, verify_jwt_token, jwt_required

# Create blueprint for API routes
api = Blueprint('api', __name__)


# ============================================================================
# PUBLIC APIs (No Authentication Required)
# ============================================================================

@api.route('/health', methods=['GET'])
def health_check():
    """
    Health check endpoint.
    
    Purpose:
    - Kubernetes liveness/readiness probes
    - Load balancer health checks
    - Monitoring and alerting systems
    
    This endpoint MUST be publicly accessible (no auth).
    Kong is configured to bypass JWT validation for this route.
    
    Returns:
        200 OK with status information
    """
    return jsonify({
        'status': 'healthy',
        'service': 'user-service',
        'version': '1.0.0'
    }), 200


@api.route('/verify', methods=['GET'])
def verify_token():
    """
    Verify JWT token validity.
    
    This endpoint allows clients to check if their token is still valid
    without making an authenticated request.
    
    Why public access?
    - Clients need to verify tokens before using them
    - Reduces unnecessary authenticated calls
    - Useful for token refresh logic
    
    Query Parameters:
        token: The JWT token to verify
        
    Returns:
        200 OK with token info if valid
        401 Unauthorized if invalid/expired
    """
    # Accept token from query param or Authorization header
    token = request.args.get('token')
    
    if not token:
        auth_header = request.headers.get('Authorization', '')
        if auth_header.startswith('Bearer '):
            token = auth_header[7:]
    
    if not token:
        return jsonify({
            'valid': False,
            'error': 'No token provided. Use ?token=<jwt> or Authorization header'
        }), 400
    
    is_valid, result = verify_jwt_token(token)
    
    if is_valid:
        return jsonify({
            'valid': True,
            'payload': {
                'user_id': result['sub'],
                'username': result['username'],
                'issued_at': result['iat'],
                'expires_at': result['exp']
            }
        }), 200
    else:
        return jsonify({
            'valid': False,
            'error': result
        }), 401


# ============================================================================
# AUTHENTICATION APIs
# ============================================================================

@api.route('/login', methods=['POST'])
def login():
    """
    Authenticate user and return JWT token.
    
    Request Body (JSON):
        {
            "username": "string",
            "password": "string"
        }
    
    Authentication Flow:
    1. Receive username/password
    2. Lookup user in SQLite database
    3. Verify password hash using bcrypt
    4. Generate JWT token with user claims
    5. Return token to client
    
    The returned token should be used in subsequent requests:
        Authorization: Bearer <token>
    
    Returns:
        200 OK with JWT token if authenticated
        401 Unauthorized if credentials invalid
        400 Bad Request if missing fields
    """
    # Get JSON body
    data = request.get_json()
    
    if not data:
        return jsonify({'error': 'Request body required'}), 400
    
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': 'Username and password required'}), 400
    
    # Lookup user in database
    user = get_user_by_username(username)
    
    if not user:
        # Use generic message to prevent user enumeration attacks
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Verify password
    if not verify_password(password, user['password_hash']):
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Generate JWT token
    token = create_jwt_token(user['id'], user['username'])
    
    return jsonify({
        'message': 'Login successful',
        'token': token,
        'user': {
            'id': user['id'],
            'username': user['username'],
            'email': user['email']
        }
    }), 200


# ============================================================================
# PROTECTED APIs (JWT Authentication Required)
# ============================================================================

@api.route('/users', methods=['GET'])
@jwt_required
def list_users():
    """
    List all users in the system.
    
    This is a protected endpoint requiring JWT authentication.
    
    Authentication:
    1. Kong validates JWT at gateway level
    2. This decorator provides additional app-level validation
    
    This demonstrates the concept of "defense in depth":
    - Multiple layers of security
    - Even if one layer fails, others protect the resource
    
    Headers Required:
        Authorization: Bearer <jwt_token>
    
    Returns:
        200 OK with list of users (without password hashes)
        401 Unauthorized if not authenticated
    """
    # Get current user from token (set by jwt_required decorator)
    current_user = request.current_user
    
    # Fetch all users from database
    users = get_all_users()
    
    return jsonify({
        'users': users,
        'total': len(users),
        'requested_by': current_user['username']
    }), 200

