#!/bin/bash
# Lint and format documentation files

set -e

echo "📝 Linting documentation"
echo "======================="

# Check if tools are installed
check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed. Installing..."
        return 1
    fi
    return 0
}

# Install tools if needed
if ! check_tool mdformat; then
    # Use uv to install in the current environment
    echo "Installing mdformat with uv..."
    uv pip install --system mdformat mdformat-frontmatter mdformat-tables
fi

if ! check_tool markdownlint; then
    echo "Installing markdownlint-cli2..."
    npm install -g markdownlint-cli2 || echo "Note: npm install failed, please install markdownlint-cli2 manually"
fi

# Format markdown files
echo "Formatting markdown files..."
find docs -name "*.md" -type f -exec mdformat {} \;
mdformat *.md || true

# Validate frontmatter
echo ""
echo "Validating frontmatter..."
python3 << 'EOF'
import os
import yaml
from pathlib import Path

def validate_frontmatter(file_path):
    """Validate that markdown file has proper frontmatter."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    if not content.startswith('---\n'):
        return False, "Missing frontmatter"
    
    try:
        # Extract frontmatter
        parts = content.split('---\n', 2)
        if len(parts) < 3:
            return False, "Invalid frontmatter format"
        
        frontmatter = yaml.safe_load(parts[1])
        
        # Required fields
        required_fields = ['title', 'description', 'date']
        missing_fields = [field for field in required_fields if field not in frontmatter]
        
        if missing_fields:
            return False, f"Missing required fields: {', '.join(missing_fields)}"
        
        return True, "Valid"
    except Exception as e:
        return False, f"Error parsing frontmatter: {str(e)}"

# Check all markdown files in docs directory
docs_dir = Path('docs')
errors = []

for md_file in docs_dir.rglob('*.md'):
    valid, message = validate_frontmatter(md_file)
    if not valid:
        errors.append(f"{md_file}: {message}")
    else:
        print(f"✅ {md_file}")

if errors:
    print("\n❌ Frontmatter validation errors:")
    for error in errors:
        print(f"  - {error}")
    exit(1)
else:
    print("\n✅ All files have valid frontmatter")
EOF

# Lint markdown files
echo ""
echo "Linting markdown files..."
markdownlint-cli2 "docs/**/*.md" "*.md"

echo ""
echo "✅ Documentation linting complete!"