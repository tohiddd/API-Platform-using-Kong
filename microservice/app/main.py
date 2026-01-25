"""
Main entry point for the User Service Flask application.

This module:
- Creates and configures the Flask application
- Registers API blueprints
- Initializes the database
- Starts the server

Key Concept: Flask Application Factory Pattern
----------------------------------------------
While this is a simple setup, the pattern used here can be extended
to the application factory pattern for larger applications:
- create_app() function that returns configured app
- Enables testing with different configurations
- Supports multiple app instances
"""

from flask import Flask, jsonify
from .config import Config
from .database import init_db
from .routes import api


def create_app():
    """
    Create and configure the Flask application.
    
    Returns:
        Configured Flask application instance
    """
    app = Flask(__name__)
    
    # Load configuration
    app.config.from_object(Config)
    
    # Register API blueprint at root level
    # Routes will be accessible at /health, /login, /users, etc.
    # Kong will route to these endpoints
    app.register_blueprint(api)
    
    # Global error handlers
    @app.errorhandler(404)
    def not_found(error):
        return jsonify({'error': 'Resource not found'}), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({'error': 'Internal server error'}), 500
    
    # Root endpoint
    @app.route('/')
    def root():
        return jsonify({
            'service': 'user-service',
            'version': '1.0.0',
            'endpoints': {
                'health': '/health',
                'login': '/login',
                'verify': '/verify',
                'users': '/users (requires JWT)'
            }
        })
    
    return app


# Application instance
app = create_app()

# Initialize database when module is imported (for gunicorn)
# This ensures the database is ready before handling requests
print("Initializing database...")
init_db()


def main():
    """
    Main entry point - initializes database and starts server.
    """
    # Initialize database (creates tables and seeds data if needed)
    print("Initializing database...")
    init_db()
    
    # Start Flask development server
    # In production, use gunicorn or uwsgi instead
    print(f"Starting User Service on {Config.HOST}:{Config.PORT}")
    app.run(
        host=Config.HOST,
        port=Config.PORT,
        debug=Config.DEBUG
    )


if __name__ == '__main__':
    main()

