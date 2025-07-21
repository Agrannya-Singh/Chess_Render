# Use the official Python 3.9 slim image as the base
FROM python:3.9-slim

# Install necessary system dependencies (wget, tar, and coreutils for the 'install' command).
# We chain these commands with '&& \' to keep them within a single RUN instruction,
# and then clean up the apt cache to keep the image size down.
RUN apt-get update && \
    apt-get install -y wget tar coreutils && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /app

# Copy the Python requirements file and install the dependencies.
# '--no-cache-dir' helps reduce image size by not storing pip's cache.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application's source code into the container
COPY . .

# Download, extract, and install the Stockfish binary.
# The 'install -m 755' command is used here to copy the binary and
# simultaneously set its permissions to be executable (755).
# This is more robust than 'mv' followed by 'chmod'.
# All these operations are chained in a single RUN command to prevent
# "unknown instruction" errors and optimize Docker layers.
RUN wget https://github.com/official-stockfish/Stockfish/releases/latest/download/stockfish-ubuntu-x86-64-avx2.tar && \
    tar -xvf stockfish-ubuntu-x86-64-avx2.tar && \
    install -m 755 stockfish /usr/local/bin/stockfish && \
    rm stockfish-ubuntu-x86-64-avx2.tar

# Verify that Stockfish was correctly installed and is executable.
# This step helps confirm the previous RUN command was successful.
RUN ls -l /usr/local/bin/stockfish

# Explicitly set the user to root. While this is often the default,
# being explicit can improve clarity for others reading the Dockerfile.
USER root

# Set an environment variable for the Stockfish path, which your application
# might use to locate the engine.
ENV STOCKFISH_PATH=/usr/local/bin/stockfish

# Define the command to run your application using Uvicorn when the container starts.
# It listens on all network interfaces (0.0.0.0) on port 8000.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
