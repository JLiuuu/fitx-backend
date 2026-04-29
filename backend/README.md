# FitX AI Backend

Production-ready baseline backend for FitX AI proxy.

## Features

- `POST /api/assistant/workout`
- `POST /api/assistant/meal`
- `POST /api/assistant/chat`
- `GET /health`
- Gemini server-side proxy (no client key exposure)
- Optional API key auth (`BACKEND_API_KEY`)
- Basic in-memory rate limit (`RATE_LIMIT_PER_MINUTE`)

## Quick Start

1. Create virtual env and install dependencies:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Configure environment:

```bash
cp .env.example .env
```

Set at least:

- `GEMINI_API_KEY=...`

3. Run server:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

4. Test endpoints:

```bash
curl -X POST "http://localhost:8000/api/assistant/chat" \
  -H "Content-Type: application/json" \
  -d '{"userId":"demo","message":"What should I train today?"}'
```

## Cloud Deploy (Render - easiest)

1. Push this repo to GitHub.
2. Go to [Render](https://render.com) and create a new **Blueprint** service.
3. Select this repo (the included `render.yaml` will be detected).
4. In Render env vars, set:
   - `GEMINI_API_KEY` = your key (required)
   - Optional: `BACKEND_API_KEY` if you want backend-level auth
5. Deploy and wait until health check `/health` is green.
6. Copy your Render URL, e.g. `https://fitx-ai-backend.onrender.com`.

Then set iOS `FITNESS_BACKEND_URL` to that URL.

## iOS Integration

In your `FitX iOS` Scheme environment variables:

- `FITX_RUNTIME_MODE=release`
- `FITNESS_BACKEND_URL=https://your-backend-domain`

If you enabled `BACKEND_API_KEY`, then add matching header support in iOS client.

## Cloud Deployment Checklist

- Keep `FITX_RUNTIME_MODE=release` on iOS target.
- Use HTTPS backend URL only.
- Never store `GEMINI_API_KEY` in iOS app env vars.
- Verify these endpoints from browser/curl:
  - `GET /health`
  - `POST /api/assistant/chat`
  - `POST /api/assistant/workout`
  - `POST /api/assistant/meal`

## Production Notes

- Replace in-memory rate limit with Redis-based limiter for multi-instance deployments.
- Add structured logs (Datadog/OpenTelemetry).
- Add request auth tied to app user identity.
- Run behind HTTPS reverse proxy (Cloud Run, Fly.io, Render, Railway, ECS, etc.).
