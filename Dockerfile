FROM python:3.9-slim

# Install dependencies for Stockfish
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .

# Add Stockfish (download during build)
RUN wget https://stockfishchess.org/files/stockfish_15.1_linux_x64.zip && \
    unzip stockfish_15.1_linux_x64.zip && \
    mv stockfish_15.1_linux_x64/stockfish /usr/local/bin/ && \
    rm -rf stockfish_15.1_linux_x64.zip stockfish_15.1_linux_x64

ENV STOCKFISH_PATH=/usr/local/bin/stockfish

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "$PORT"]