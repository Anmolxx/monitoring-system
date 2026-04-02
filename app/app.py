#!/usr/bin/env python3
import logging
import logging.handlers
import os
import json
import random
import time
from datetime import datetime
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from prometheus_client.core import REGISTRY

# Create Flask app
app = Flask(__name__)

# ============= LOGGING CONFIGURATION =============
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

# Create logs directory if it doesn't exist
LOG_DIR = "/app/logs"
os.makedirs(LOG_DIR, exist_ok=True)

# Create formatter
formatter = logging.Formatter(
    '%(asctime)s [%(levelname)s] %(name)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# File handler
file_handler = logging.FileHandler(os.path.join(LOG_DIR, 'app.log'))
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

# Console handler (stdout)
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.DEBUG)
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

# ============= PROMETHEUS METRICS =============
# HTTP request counter
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

# HTTP request duration histogram
http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0)
)

# Application errors counter
app_errors_total = Counter(
    'app_errors_total',
    'Total application errors',
    ['endpoint', 'error_type']
)

# Active requests gauge
active_requests = Gauge(
    'http_active_requests',
    'Number of active HTTP requests',
    ['method', 'endpoint']
)

# ============= MIDDLEWARE =============
@app.before_request
def before_request():
    """Track request start time and active requests."""
    request.start_time = time.time()
    active_requests.labels(method=request.method, endpoint=request.path).inc()
    logger.info(f"{request.method} {request.path} started")

@app.after_request
def after_request(response):
    """Track request duration and record metrics."""
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time
        active_requests.labels(method=request.method, endpoint=request.path).dec()
        
        # Record metrics
        http_requests_total.labels(
            method=request.method,
            endpoint=request.path,
            status=response.status_code
        ).inc()
        
        http_request_duration_seconds.labels(
            method=request.method,
            endpoint=request.path
        ).observe(duration)
        
        logger.info(
            f"{request.method} {request.path} completed with status {response.status_code} "
            f"in {duration:.3f}s"
        )
    
    return response

# ============= ROUTES =============
@app.route('/', methods=['GET'])
def home():
    """Health check and status endpoint."""
    logger.info("Home endpoint accessed")
    return jsonify({
        "status": "ok",
        "message": "Monitoring Demo App - version4",
        "timestamp": datetime.utcnow().isoformat()
    }), 200

@app.route('/health', methods=['GET'])
def health():
    """Liveness probe endpoint."""
    logger.info("Health check passed")
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }), 200

@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint."""
    logger.debug("Metrics endpoint accessed")
    return generate_latest(REGISTRY), 200, {'Content-Type': 'text/plain; charset=utf-8'}

@app.route('/data', methods=['GET'])
def get_data():
    """Return random data endpoint."""
    data = {
        "id": random.randint(1, 10000),
        "value": random.uniform(0, 100),
        "status": random.choice(["active", "inactive", "pending"]),
        "timestamp": datetime.utcnow().isoformat()
    }
    logger.info(f"Data endpoint returned: id={data['id']}, value={data['value']:.2f}")
    return jsonify(data), 200

@app.route('/simulate/error', methods=['GET'])
def simulate_error():
    """Simulate an application error."""
    try:
        logger.error("Simulating application error - intentional error triggered")
        app_errors_total.labels(endpoint='/simulate/error', error_type='intentional').inc()
        raise Exception("Intentional error for monitoring")
    except Exception as e:
        logger.error(f"Error occurred: {str(e)}", exc_info=True)
        return jsonify({
            "status": "error",
            "message": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

@app.route('/simulate/load', methods=['GET'])
def simulate_load():
    """Simulate CPU-intensive work."""
    logger.info("Starting CPU-intensive load simulation (2 seconds)")
    start_time = time.time()
    
    # Simple CPU-intensive loop
    result = 0
    for i in range(200000000):
        result += i % 7
    
    elapsed = time.time() - start_time
    logger.info(f"CPU load simulation completed in {elapsed:.2f}s")
    
    return jsonify({
        "status": "success",
        "message": "Load simulation completed",
        "duration": elapsed,
        "timestamp": datetime.utcnow().isoformat()
    }), 200

@app.route('/readiness', methods=['GET'])
def readiness():
    """Readiness probe endpoint."""
    logger.debug("Readiness check passed")
    return jsonify({
        "status": "ready",
        "timestamp": datetime.utcnow().isoformat()
    }), 200

# ============= ERROR HANDLERS =============
@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    logger.warning(f"404 error for path: {request.path}")
    app_errors_total.labels(endpoint=request.path, error_type='not_found').inc()
    return jsonify({
        "status": "error",
        "message": "Resource not found",
        "timestamp": datetime.utcnow().isoformat()
    }), 404

@app.errorhandler(500)
def server_error(error):
    """Handle 500 errors."""
    logger.error(f"500 error: {str(error)}", exc_info=True)
    app_errors_total.labels(endpoint=request.path, error_type='server_error').inc()
    return jsonify({
        "status": "error",
        "message": "Internal server error",
        "timestamp": datetime.utcnow().isoformat()
    }), 500

# ============= MAIN =============
if __name__ == '__main__':
    logger.info("Starting Flask application on 0.0.0.0:5000")
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
