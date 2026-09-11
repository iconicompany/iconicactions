#!/usr/bin/env bash
set -e

# ==============================================================================
# Script: create-static-project.sh
# Purpose: Create a GitHub repo for a static HTML project with Docker/Nginx,
#          Werf/Helm k8s deployment, and GitHub Actions workflow.
# Usage: ./create-static-project.sh <STATIC_DIR> [GITHUB_REPO] [TARGET_DIR] [--public|--private]
# Example: ./create-static-project.sh /home/slavb18/work/tenders/projects/agroeco-transport iconicompany/agroecotransport
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to show usage
usage() {
    echo "Usage: $0 <STATIC_DIR> [GITHUB_REPO] [TARGET_DIR] [--public|--private]"
    echo ""
    echo "Arguments:"
    echo "  STATIC_DIR   Path to directory containing static HTML files (required)"
    echo "  GITHUB_REPO  GitHub repo name, e.g. iconicompany/agroecotransport or agroecotransport (default: iconicompany/<derived-name>)"
    echo "  TARGET_DIR   Path where local repo will be created (default: <STATIC_DIR-parent>/<PROJECT_NAME>)"
    echo "  --public     Create public repository on GitHub (default: private)"
    echo "  --private    Create private repository on GitHub"
    exit 1
}

if [ -z "$1" ] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

STATIC_DIR="$(readlink -f "$1")"
if [ ! -d "$STATIC_DIR" ]; then
    echo "Error: Directory '$STATIC_DIR' does not exist."
    exit 1
fi

# Parse positional arguments and flags
GITHUB_REPO_ARG=""
TARGET_DIR_ARG=""
VISIBILITY="--private"

shift 1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --public)
            VISIBILITY="--public"
            shift
            ;;
        --private)
            VISIBILITY="--private"
            shift
            ;;
        *)
            if [ -z "$GITHUB_REPO_ARG" ]; then
                GITHUB_REPO_ARG="$1"
            elif [ -z "$TARGET_DIR_ARG" ]; then
                TARGET_DIR_ARG="$1"
            fi
            shift
            ;;
    esac
done

# Determine GitHub Organization and Project Name
if [ -n "$GITHUB_REPO_ARG" ]; then
    if [[ "$GITHUB_REPO_ARG" == *"/"* ]]; then
        GH_ORG="$(echo "$GITHUB_REPO_ARG" | cut -d'/' -f1)"
        PROJECT_NAME="$(echo "$GITHUB_REPO_ARG" | cut -d'/' -f2)"
    else
        GH_ORG="iconicompany"
        PROJECT_NAME="$GITHUB_REPO_ARG"
    fi
else
    GH_ORG="iconicompany"
    DIR_NAME="$(basename "$STATIC_DIR")"
    PROJECT_NAME="$(echo "$DIR_NAME" | tr -d '-' | tr '[:upper:]' '[:lower:]')"
fi

# Clean project name for Helm / Kubernetes resource naming compliance (alphanumeric and hyphens only, lowercase)
PROJECT_NAME="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"
FULL_REPO="$GH_ORG/$PROJECT_NAME"

# Determine local target project directory
if [ -n "$TARGET_DIR_ARG" ]; then
    TARGET_DIR="$(readlink -f "$TARGET_DIR_ARG" 2>/dev/null || echo "$TARGET_DIR_ARG")"
else
    PARENT_DIR="$(dirname "$STATIC_DIR")"
    TARGET_DIR="$PARENT_DIR/$PROJECT_NAME"
fi

echo "=========================================================="
echo "🚀 Creating Static Site Project"
echo "  Source Directory : $STATIC_DIR"
echo "  GitHub Repo      : $FULL_REPO"
echo "  Target Directory : $TARGET_DIR"
echo "  Visibility       : ${VISIBILITY#--}"
echo "=========================================================="

# 1. Create target directory and copy static files
echo "📁 Copying static files to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

if [ "$STATIC_DIR" != "$TARGET_DIR" ]; then
    cp -r "$STATIC_DIR"/* "$TARGET_DIR"/ 2>/dev/null || true
    # Copy hidden files if any (ignoring . and ..)
    find "$STATIC_DIR" -maxdepth 1 -name ".*" ! -name "." ! -name ".." -exec cp -r {} "$TARGET_DIR"/ \; 2>/dev/null || true
fi

# 2. Check for index.html or generate one
if [ ! -f "$TARGET_DIR/index.html" ]; then
    echo "💡 index.html not found. Generating landing index.html..."
    HTML_FILES=$(find "$TARGET_DIR" -maxdepth 1 -name "*.html" -exec basename {} \; | sort)
    
    CARD_ITEMS=""
    for file in $HTML_FILES; do
        TITLE=$(grep -i "<title>" "$TARGET_DIR/$file" | sed -e 's/<[^>]*>//g' | xargs || echo "$file")
        CARD_ITEMS="${CARD_ITEMS}
        <a href=\"$file\" class=\"card\">
            <div class=\"card-title\">$TITLE</div>
            <div class=\"card-file\">$file</div>
        </a>"
    done

    cat << EOF > "$TARGET_DIR/index.html"
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$PROJECT_NAME - Navigation</title>
    <style>
        :root {
            --bg: #0f172a;
            --card-bg: #1e293b;
            --card-hover: #334155;
            --text: #f8fafc;
            --accent: #38bdf8;
            --subtext: #94a3b8;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg);
            color: var(--text);
            margin: 0;
            padding: 2rem;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        header {
            margin-bottom: 2.5rem;
            border-bottom: 1px solid var(--card-hover);
            padding-bottom: 1rem;
        }
        h1 {
            font-size: 2.25rem;
            font-weight: 700;
            color: var(--accent);
            margin: 0 0 0.5rem 0;
        }
        p {
            color: var(--subtext);
            margin: 0;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 1.5rem;
        }
        .card {
            background-color: var(--card-bg);
            border: 1px solid var(--card-hover);
            border-radius: 0.75rem;
            padding: 1.25rem;
            text-decoration: none;
            color: inherit;
            transition: all 0.2s ease-in-out;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }
        .card:hover {
            transform: translateY(-2px);
            border-color: var(--accent);
            box-shadow: 0 10px 25px -5px rgba(56, 189, 248, 0.1);
        }
        .card-title {
            font-size: 1.1rem;
            font-weight: 600;
            color: var(--text);
            margin-bottom: 0.5rem;
        }
        .card-file {
            font-size: 0.85rem;
            color: var(--accent);
            font-family: monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>$PROJECT_NAME</h1>
            <p>Просмотр страниц и интерфейсов проекта</p>
        </header>
        <div class="grid">
            $CARD_ITEMS
        </div>
    </div>
</body>
</html>
EOF
fi

# 3. Copy Helm templates, Werf & GitHub workflows from template source
echo "🛠️ Configuring Werf, Helm charts & GitHub Actions..."

if [ -d "$SCRIPT_DIR/.helm" ]; then
    cp -r "$SCRIPT_DIR/.helm" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/werf.yaml" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/werf.sh" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/build.sh" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/runit.sh" "$TARGET_DIR/"
    mkdir -p "$TARGET_DIR/.github/workflows"
    cp "$SCRIPT_DIR/.github/workflows/deployment-"*.yml "$TARGET_DIR/.github/workflows/"
else
    # Fallback to downloading iconicactions main if run outside iconicactions repo
    TMP_DIR=$(mktemp -d)
    curl -sLo "$TMP_DIR/iconicactions.zip" https://github.com/iconicompany/iconicactions/archive/refs/heads/main.zip
    unzip -q "$TMP_DIR/iconicactions.zip" -d "$TMP_DIR"
    cp -r "$TMP_DIR/iconicactions-main/.helm" "$TARGET_DIR/"
    cp "$TMP_DIR/iconicactions-main/werf.yaml" "$TARGET_DIR/"
    cp "$TMP_DIR/iconicactions-main/werf.sh" "$TARGET_DIR/"
    cp "$TMP_DIR/iconicactions-main/build.sh" "$TARGET_DIR/"
    cp "$TMP_DIR/iconicactions-main/runit.sh" "$TARGET_DIR/"
    mkdir -p "$TARGET_DIR/.github/workflows"
    cp "$TMP_DIR/iconicactions-main/.github/workflows/deployment-"*.yml "$TARGET_DIR/.github/workflows/"
    rm -rf "$TMP_DIR"
fi

# 4. Create Nginx Dockerfile, nginx.conf and .dockerignore for static site
echo "🐳 Creating Nginx Dockerfile & configuration..."

cat << 'EOF' > "$TARGET_DIR/Dockerfile"
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static site files
COPY . /usr/share/nginx/html

EXPOSE 3000

CMD ["nginx", "-g", "daemon off;"]
EOF

cat << 'EOF' > "$TARGET_DIR/nginx.conf"
server {
    listen 3000;
    server_name _;

    root /usr/share/nginx/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ /index.html =404;
    }

    location ~* \.(?:css|js|jpg|jpeg|gif|png|ico|cur|gz|svg|svgz|mp4|ogg|ogv|webm|htc|woff|woff2|ttf)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }
}
EOF

cat << 'EOF' > "$TARGET_DIR/.dockerignore"
.git
.gitignore
.github
.helm
werf.yaml
werf.sh
build.sh
runit.sh
.env*
*.md
EOF

# 5. Customize placeholders for target project
echo "✏️ Customizing configuration placeholders for project '$PROJECT_NAME'..."

# Replace iconicactions with project name in Werf, scripts, workflows
grep -Rl "iconicactions" "$TARGET_DIR/werf.yaml" "$TARGET_DIR/werf.sh" "$TARGET_DIR/build.sh" "$TARGET_DIR/runit.sh" "$TARGET_DIR/.github/workflows/" | xargs sed -i "s/iconicactions/$PROJECT_NAME/g"

# Set workflow call to point to reusable workflow in iconicompany/iconicactions
sed -i "s^\./\.github/workflows/deployment\.yml^iconicompany/iconicactions/.github/workflows/deployment.yml@main^g" "$TARGET_DIR/.github/workflows/deployment-"*.yml

# 6. Initialize Git & push to GitHub
echo "octocat: Initializing Git repository and pushing to GitHub ($FULL_REPO)..."
cd "$TARGET_DIR"

if [ ! -d ".git" ]; then
    git init -b main
else
    git checkout -B main 2>/dev/null || true
fi

# Ensure basic .gitignore
if [ ! -f ".gitignore" ]; then
    cat << 'EOF' > .gitignore
.werf
.env
.env.local
node_modules
*.log
EOF
fi

git add .

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    git commit -m "Initial commit: static Nginx site with werf/helm CI/CD"
fi

# Check if GitHub repo already exists
if gh repo view "$FULL_REPO" >/dev/null 2>&1; then
    echo "GitHub repository $FULL_REPO already exists. Setting remote origin..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "git@github.com:$FULL_REPO.git" || git remote add origin "https://github.com/$FULL_REPO.git"
else
    echo "Creating GitHub repository $FULL_REPO..."
    gh repo create "$FULL_REPO" $VISIBILITY --source=. --remote=origin
fi

echo "Pushing code to GitHub..."
git push -u origin main --force

echo "=========================================================="
echo "✅ Project successfully created and pushed to GitHub!"
echo "   Repository: https://github.com/$FULL_REPO"
echo "   Local path: $TARGET_DIR"
echo "   Actions   : https://github.com/$FULL_REPO/actions"
echo "=========================================================="
