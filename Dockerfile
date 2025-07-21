FROM python:3.9-slim

# Install dependencies for Stockfish
RUN apt-get update && apt-get install -y wget tar && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .

# Download and extract Stockfish
RUN wget https://github.com/official-stockfish/Stockfish/releases/latest/download/stockfish-ubuntu-x86-64-avx2.tar && \
    tar -xvf stockfish-ubuntu-x86-64-avx2.tar && \
    mv stockfish-ubuntu-x86-64-avx2/stockfish /usr/local/bin/ && \
    rm -rf stockfish-ubuntu-x86-64-avx2.tar stockfish-ubuntu-x86-64-avx2

ENV STOCKFISH_PATH=/usr/local/bin/stockfish

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "$PORT"]
