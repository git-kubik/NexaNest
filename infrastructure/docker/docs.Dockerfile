# MkDocs documentation server  
FROM python:3.12-slim

# Install MkDocs and dependencies directly
RUN pip install \
    mkdocs \
    mkdocs-material \
    pymdown-extensions \
    mkdocs-mermaid2-plugin \
    mkdocs-git-revision-date-localized-plugin

# Set working directory
WORKDIR /docs

# Copy documentation files
COPY mkdocs.yml .
COPY docs/ ./docs/

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Serve documentation
CMD ["mkdocs", "serve", "--dev-addr", "0.0.0.0:8080"]