#!/bin/sh

git add .
git commit -m "$msg at: $(date + '%Y-%m-%d %H:%M:%S')"
git push origin main