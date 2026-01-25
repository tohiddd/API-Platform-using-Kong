# =============================================================================
# Dockerfile for User Service Microservice
# =============================================================================
#
# Key Concepts:
# -------------
# 1. Multi-stage builds: Use multiple FROM statements to optimize image size
# 2. Layer caching: Order commands from least to most frequently changed
# 3. Non-root user: Run as non-root for security
# 4. Health checks: Built-in container health monitoring
#
# Base Image Choice:
# - python:3.11-slim: Debian-based, smaller than full python image
# - Alpine alternative: python:3.11-alpine (even smaller but may have compatibility issues)
#

# Stage 1: Build stage
FROM python:3.11-slim as builder

# Set working directory
WORKDIR /app

# Install build dependencies
# These are needed to compile bcrypt and other native extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (leverages Docker layer caching)
# If requirements.txt hasn't changed, this layer is cached
COPY requirements.txt .

# Install Python dependencies
# --user installs to user directory (useful for copying to final stage)
RUN pip install --user --no-cache-dir -r requirements.txt


# Stage 2: Production stage
FROM python:3.11-slim

# Labels for container metadata
LABEL maintainer="DevOps Team"
LABEL description="User Service Microservice with JWT Authentication"
LABEL version="1.0.0"

# Set environment variables
# PYTHONUNBUFFERED: Force Python to not buffer stdout/stderr
#   This ensures logs appear immediately (important for container logging)
# PYTHONDONTWRITEBYTECODE: Don't write .pyc files
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    # Application settings (can be overridden at runtime)
    FLASK_HOST=0.0.0.0 \
    FLASK_PORT=5000 \
    DATABASE_PATH=/app/data/users.db

# Create non-root user for security
# Running as root in containers is a security risk
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory
WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Update PATH to include user-installed packages
ENV PATH=/home/appuser/.local/bin:$PATH

# Create data directory for SQLite database
# This directory should be mounted as a volume for persistence
RUN mkdir -p /app/data && chown -R appuser:appuser /app/data

# Copy application code
COPY --chown=appuser:appuser app/ ./app/

# Switch to non-root user
USER appuser

# Expose the application port
# This is documentation; actual port mapping is done at runtime
EXPOSE 5000

# Health check for container orchestration
# Kubernetes can use this, but typically uses its own probe definitions
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Default command: Run with Gunicorn (production WSGI server)
# Workers: Typically 2-4 x number of CPU cores
# Bind: Listen on all interfaces at specified port
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app.main:app"]

# Alternative: Run with Flask development server (NOT for production)
# CMD ["python", "-m", "app.main"]

