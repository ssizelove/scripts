#!/bin/bash
set -e

echo "🔄 Pushing ADHD app..."
cd ~/dev/adhd_app
git add -A
git commit -m "update" || true
git pull --rebase --autostash origin main
git push origin main

echo "🔄 Pushing scripts..."
cd ~/scripts
git add -A
git commit -m "update" || true
git pull --rebase --autostash origin main
git push origin main

echo "✅ All changes pushed!"
