#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo "Created backend/.env from .env.example"
  echo "Please set GEMINI_API_KEY in backend/.env and run again."
  exit 1
fi

source .venv/bin/activate
pip install -r requirements.txt >/dev/null
uvicorn main:app --host 0.0.0.0 --port "${PORT:-8000}" --reload
