#!/bin/bash
# Auto-update ArgoCD application.yaml with current GitHub repository URL
# Usage: ./scripts/update-argocd-repo.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARGOCD_APP="$REPO_ROOT/argocd-unified/application.yaml"

# Get GitHub repository URL from git remote
GIT_REPO_URL=$(git -C "$REPO_ROOT" config --get remote.origin.url)

# Convert SSH URL to HTTPS if needed
if [[ "$GIT_REPO_URL" == git@github.com:* ]]; then
  # Convert git@github.com:org/repo.git to https://github.com/org/repo.git
  GIT_REPO_URL=$(echo "$GIT_REPO_URL" | sed 's|git@github.com:|https://github.com/|' | sed 's|\.git$|.git|')
elif [[ "$GIT_REPO_URL" != https://github.com/* ]]; then
  echo "⚠️  Warning: Repository URL format not recognized: $GIT_REPO_URL"
  echo "   Please update argocd-unified/application.yaml manually"
  exit 1
fi

# Ensure it ends with .git
if [[ "$GIT_REPO_URL" != *.git ]]; then
  GIT_REPO_URL="${GIT_REPO_URL}.git"
fi

echo "Detected GitHub repository: $GIT_REPO_URL"
echo "Updating ArgoCD application manifest..."

# Update the repoURL in application.yaml
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS uses BSD sed
  sed -i '' "s|repoURL:.*|repoURL: $GIT_REPO_URL|" "$ARGOCD_APP"
else
  # Linux uses GNU sed
  sed -i "s|repoURL:.*|repoURL: $GIT_REPO_URL|" "$ARGOCD_APP"
fi

echo "✅ Updated argocd-unified/application.yaml"
echo ""
echo "Verification:"
grep "repoURL:" "$ARGOCD_APP"
