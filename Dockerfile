# Use the official Python 3.9 slim image as the base.
# This provides a minimal Python environment.
FROM python:3.9-slim

# Install essential system dependencies.
# - wget: To download files from the internet.
# - tar: To extract the downloaded Stockfish archive.
# - coreutils: Provides the 'install' command, which is a robust way to copy files
#              and set permissions in one step.
# All commands are chained with '&& \' to ensure they run in a single layer,
# optimizing image size and build time.
# 'rm -rf /var/lib/apt/lists/*' cleans up the apt cache to further reduce image size.
RUN apt-get update && \
    apt-get install -y wget tar coreutils && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container.
# All subsequent commands will be executed relative to this directory.
WORKDIR /app

# Copy the Python requirements file into the working directory.
# This step is done separately to leverage Docker's build cache.
COPY requirements.txt .

# Install the Python dependencies listed in requirements.txt.
# '--no-cache-dir' prevents pip from storing its cache, saving image space.
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application's source code into the working directory.
COPY . .

# Download, extract, and install the Stockfish chess engine binary.
# Using a direct SourceForge link for a specific stable release (Stockfish 16.1)
# to avoid issues with GitHub's 'latest' redirect.
# 1. wget: Downloads the specific Stockfish tarball.
# 2. tar -xvf: Extracts the 'stockfish' binary from the tarball.
# 3. install -m 755: Copies the extracted 'stockfish' binary to /usr/local/bin/
#    and sets its permissions to 755 (read/write/execute for owner, read/execute for group/others).
# 4. rm: Removes the downloaded tarball to keep the final image clean.
# All these operations are combined into a single RUN instruction.
RUN wget https://sourceforge.net/projects/stockfish.mirror/files/sf_16.1/stockfish-ubuntu-x86-64-avx2.tar/download -O stockfish-ubuntu-x86-64-avx2.tar && \
    tar -xvf stockfish-ubuntu-x86-64-avx2.tar && \
    install -m 755 stockfish /usr/local/bin/stockfish && \
    rm stockfish-ubuntu-x86-64-avx2.tar

# Verify the Stockfish binary's presence and permissions.
# This helps confirm that the installation step was successful.
RUN ls -l /usr/local/bin/stockfish

# Explicitly set the user to 'root'.
# While 'RUN' commands execute as root by default, this ensures the container
# runs as root for the subsequent 'CMD' if not overridden.
USER root

# Set an environment variable to specify the path to the Stockfish executable.
# Your Python application can then use this environment variable to find Stockfish.
ENV STOCKFISH_PATH=/usr/local/bin/stockfish

# Define the default command to run when the container starts.
# It uses Uvicorn to serve your 'main:app' (assuming 'main.py' contains a FastAPI/Starlette app named 'app').
# '--host 0.0.0.0' makes the application accessible from outside the container.
# '--port 8000' specifies the port Uvicorn will listen on.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
