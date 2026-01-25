"""
Database module for SQLite operations.

This module provides:
- Database initialization with auto-creation of tables
- Password hashing using bcrypt (industry standard)
- User CRUD operations

Key Concept: SQLite
-------------------
SQLite is a self-contained, serverless, file-based SQL database.
Perfect for:
- Local development
- Small to medium applications
- Embedded databases
- Self-managed deployments (no external DB service needed)

Key Concept: Password Hashing
-----------------------------
Passwords are NEVER stored in plain text. We use bcrypt which:
- Automatically handles salt generation
- Is designed to be slow (prevents brute force attacks)
- Is adaptive (can increase work factor over time)
"""

import sqlite3
import bcrypt
import os
from contextlib import contextmanager
from .config import Config


def get_password_hash(password: str) -> str:
    """
    Hash a password using bcrypt.
    
    Args:
        password: Plain text password
        
    Returns:
        Hashed password string (includes salt)
    """
    # Generate salt and hash password
    # bcrypt automatically includes the salt in the output
    salt = bcrypt.gensalt(rounds=12)  # 12 rounds is a good balance of security/speed
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')


def verify_password(password: str, hashed: str) -> bool:
    """
    Verify a password against its hash.
    
    Args:
        password: Plain text password to verify
        hashed: Previously hashed password
        
    Returns:
        True if password matches, False otherwise
    """
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))


@contextmanager
def get_db_connection():
    """
    Context manager for database connections.
    
    Ensures proper connection handling and cleanup.
    Uses Row factory for dict-like access to columns.
    """
    conn = sqlite3.connect(Config.DATABASE_PATH)
    conn.row_factory = sqlite3.Row  # Enables column access by name
    try:
        yield conn
    finally:
        conn.close()


def init_db():
    """
    Initialize the database with required tables.
    
    This function is called at application startup.
    It creates tables if they don't exist (idempotent operation).
    Also seeds the database with sample users for testing.
    """
    # Ensure database directory exists
    db_dir = os.path.dirname(Config.DATABASE_PATH)
    if db_dir and not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)
    
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Create users table
        # id: Auto-incrementing primary key
        # username: Unique identifier for login
        # email: User's email address
        # password_hash: bcrypt hashed password (NEVER plain text)
        # created_at: Timestamp of account creation
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Seed with sample users if table is empty
        cursor.execute('SELECT COUNT(*) FROM users')
        if cursor.fetchone()[0] == 0:
            sample_users = [
                ('admin', 'admin@example.com', 'admin123'),
                ('user1', 'user1@example.com', 'password1'),
                ('user2', 'user2@example.com', 'password2'),
            ]
            for username, email, password in sample_users:
                password_hash = get_password_hash(password)
                cursor.execute(
                    'INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)',
                    (username, email, password_hash)
                )
            print(f"Database initialized with {len(sample_users)} sample users")
        
        conn.commit()
        print(f"Database initialized at {Config.DATABASE_PATH}")


def get_user_by_username(username: str) -> dict:
    """
    Retrieve a user by username.
    
    Args:
        username: The username to search for
        
    Returns:
        User dict or None if not found
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM users WHERE username = ?', (username,))
        row = cursor.fetchone()
        if row:
            return dict(row)
        return None


def get_all_users() -> list:
    """
    Retrieve all users (without password hashes).
    
    Returns:
        List of user dicts (id, username, email, created_at)
    """
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute('SELECT id, username, email, created_at FROM users')
        return [dict(row) for row in cursor.fetchall()]

