FROM python:3.9-slim

# 1. Install dependencies (wget, tar) as root by default and clean up apt cache
RUN apt-get update && apt-get install -y wget tar && rm -rf /var/lib/apt/lists/*

# 2. Set working directory
WORKDIR /app

# 3. Copy requirements and install python packages
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Copy application source code
COPY . .

# 5. Download and extract Stockfish binary, move it, and make executable
RUN wget https://github.com/official-stockfish/Stockfish/releases/latest/download/stockfish-ubuntu-x86-64-avx2.tar && \
    tar -xvf stockfish-ubuntu-x86-64-avx2.tar && \
    chmod 755 /usr/local/bin/ # Ensure /usr/local/bin is writable, even though it should be for root
    mv stockfish /usr/local/bin/stockfish && \
    chmod +x /usr/local/bin/stockfish && \
    rm stockfish-ubuntu-x86-64-avx2.tar

# 6. Confirm that the stockfish binary is executable and owned by root
RUN ls -l /usr/local/bin/stockfish

# 7. Explicitly set to run container as root user (default anyway, but explicit)
USER root

ENV STOCKFISH_PATH=/usr/local/bin/stockfish

# 8. Run your app with uvicorn on port 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
