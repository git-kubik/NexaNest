# MkDocs documentation server
FROM python:3.11-slim

# Install uv
RUN pip install uv

# Set working directory
WORKDIR /docs

# Copy project files
COPY pyproject.toml .
COPY README.md .
COPY mkdocs.yml .
COPY docs/ ./docs/

# Install MkDocs and dependencies
RUN uv pip install --system -e .

# Expose port
EXPOSE 8080

# Serve documentation
CMD ["mkdocs", "serve", "--dev-addr", "0.0.0.0:8080"]