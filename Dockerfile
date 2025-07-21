FROM python:3.9-slim

# Install dependencies for Stockfish and wget
RUN apt-get update && apt-get install -y wget tar && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Download and extract Stockfish binary
RUN wget https://github.com/official-stockfish/Stockfish/releases/latest/download/stockfish-ubuntu-x86-64-avx2.tar && \
    tar -xvf stockfish-ubuntu-x86-64-avx2.tar && \
    mv stockfish /usr/local/bin/ && \
    chmod +x /usr/local/bin/stockfish && \
    rm stockfish-ubuntu-x86-64-avx2.tar

ENV STOCKFISH_PATH=/usr/local/bin/stockfish

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
