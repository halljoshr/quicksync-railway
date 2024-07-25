# Set the python version as a build-time argument
# with Python 3.12 as the default
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}

# Create a virtual environment
RUN python -m venv /opt/venv

# Set the virtual environment as the current location
ENV PATH=/opt/venv/bin:$PATH

# Upgrade pip
RUN pip install --upgrade pip

# Set Python-related environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install os dependencies for our mini vm
RUN apt-get update && apt-get install -y \
    # for postgres
    libpq-dev \
    # for Pillow
    libjpeg-dev \
    # for CairoSVG
    libcairo2 \
    # other
    gcc \
    # for unzip
    unzip \
    # for parallel
    parallel \
    # for OpenCV
    libgl1-mesa-glx \
    libsm6 \
    libxrender1 \
    libxext6 \
    # for bun
    curl \
    # for caddy
    caddy \
    && rm -rf /var/lib/apt/lists/*

# Install bun
RUN curl -fsSL https://bun.sh/install | bash

# Ensure bun is in the PATH
ENV PATH="/root/.bun/bin:$PATH"

# Create the mini vm's code directory
RUN mkdir -p /code

# Set the working directory to that same code directory
WORKDIR /code

# Copy the requirements file into the container
COPY requirements.txt /tmp/requirements.txt

# Copy the project code into the container's working directory
COPY . .

# Install the Python project requirements
RUN pip install -r /tmp/requirements.txt

# Create a bash script to run the Reflex project
RUN printf "#!/bin/bash\n" > ./paracord_runner.sh && \
    printf "RUN_PORT=\"\${PORT:-8000}\"\n\n" >> ./paracord_runner.sh && \
    printf "yes '' | reflex init\n" >> ./paracord_runner.sh && \
    printf "reflex export --frontend-only --no-zip\n" >> ./paracord_runner.sh && \
    printf "caddy fmt --overwrite\n" >> ./paracord_runner.sh && \
    printf 'parallel --ungroup --halt now,fail=1 ::: "reflex run --backend-only --env $ENV" "caddy run 2>&1"\n' >> ./paracord_runner.sh

# Make the bash script executable
RUN chmod +x paracord_runner.sh

# Clean up apt cache to reduce image size
RUN apt-get remove --purge -y \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 8000
EXPOSE 3000
EXPOSE $PORT

# Run the Reflex project via the runtime script when the container starts
CMD ./paracord_runner.sh

# Change the CaddyFile lets try this.