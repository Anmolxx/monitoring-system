FROM python:3.11-slim

# Create app directory
WORKDIR /app

# Create logs directory
RUN mkdir -p /app/logs && chmod 777 /app/logs

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()"

# Run application
CMD ["python", "app.py"]
