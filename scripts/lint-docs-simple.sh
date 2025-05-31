#!/bin/bash
# Simple documentation linting without external dependencies

set -e

echo "📝 Linting documentation (simple)"
echo "================================"

# Validate frontmatter using basic shell commands
validate_frontmatter() {
    local file="$1"
    echo "Checking frontmatter in $file..."
    
    # Check if file starts with ---
    if ! head -n 1 "$file" | grep -q "^---$"; then
        echo "❌ $file: Missing frontmatter (should start with ---)"
        return 1
    fi
    
    # Check if there's a closing ---
    if ! sed -n '2,10p' "$file" | grep -q "^---$"; then
        echo "❌ $file: Missing frontmatter closing (no closing ---)"
        return 1
    fi
    
    # Check required fields
    local content=$(sed -n '1,/^---$/p' "$file")
    
    if ! echo "$content" | grep -q "^title:"; then
        echo "❌ $file: Missing 'title' field"
        return 1
    fi
    
    if ! echo "$content" | grep -q "^description:"; then
        echo "❌ $file: Missing 'description' field"
        return 1
    fi
    
    if ! echo "$content" | grep -q "^date:"; then
        echo "❌ $file: Missing 'date' field"
        return 1
    fi
    
    echo "✅ $file: Valid frontmatter"
    return 0
}

# Check all markdown files in docs directory
echo "Validating frontmatter..."
errors=0

for file in $(find docs -name "*.md" -type f); do
    if ! validate_frontmatter "$file"; then
        errors=$((errors + 1))
    fi
done

# Basic markdown checks
echo ""
echo "Running basic markdown checks..."

# Check for long lines (basic check)
echo "Checking for overly long lines..."
while IFS= read -r file; do
    line_num=1
    while IFS= read -r line; do
        if [ ${#line} -gt 120 ]; then
            echo "⚠️  $file:$line_num: Line too long (${#line} characters)"
        fi
        line_num=$((line_num + 1))
    done < "$file"
done < <(find docs -name "*.md" -type f)

# Check for trailing spaces
echo "Checking for trailing spaces..."
if grep -rn '[[:space:]]$' docs/*.md 2>/dev/null; then
    echo "⚠️  Found trailing spaces (shown above)"
fi

# Check for missing newline at end of file
echo "Checking for proper file endings..."
for file in $(find docs -name "*.md" -type f); do
    if [ -s "$file" ] && [ "$(tail -c1 "$file")" != "" ]; then
        echo "⚠️  $file: Missing newline at end of file"
    fi
done

if [ $errors -eq 0 ]; then
    echo ""
    echo "✅ All files have valid frontmatter"
else
    echo ""
    echo "❌ Found $errors files with frontmatter issues"
    exit 1
fi

echo ""
echo "✅ Documentation linting complete!"