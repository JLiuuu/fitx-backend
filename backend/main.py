import json
import os
import re
import time
from collections import defaultdict, deque
from typing import Any

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

load_dotenv()


class AssistantRequestPayload(BaseModel):
    userId: str
    message: str


class WorkoutAssistantAPIResponse(BaseModel):
    reply: str
    exercise: str | None = None
    sets: int | None = None
    reps: int | None = None
    weight: float | None = None
    rpe: int | None = None


class MealAssistantAPIResponse(BaseModel):
    reply: str
    name: str | None = None
    calories: int | None = None
    protein: int | None = None
    carbs: int | None = None
    fat: int | None = None


class ChatAssistantAPIResponse(BaseModel):
    reply: str


GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-flash").strip()
BACKEND_API_KEY = os.getenv("BACKEND_API_KEY", "").strip()
ALLOWED_ORIGINS = [origin.strip() for origin in os.getenv("ALLOWED_ORIGINS", "*").split(",")]
RATE_LIMIT_PER_MINUTE = int(os.getenv("RATE_LIMIT_PER_MINUTE", "60"))

app = FastAPI(title="FitX AI Backend", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_rate_limit_map: dict[str, deque[float]] = defaultdict(deque)


def _require_auth_if_enabled(x_api_key: str | None) -> None:
    if not BACKEND_API_KEY:
        return
    if x_api_key != BACKEND_API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")


def _enforce_rate_limit(client_key: str) -> None:
    now = time.time()
    window_start = now - 60
    dq = _rate_limit_map[client_key]
    while dq and dq[0] < window_start:
        dq.popleft()
    if len(dq) >= RATE_LIMIT_PER_MINUTE:
        raise HTTPException(status_code=429, detail="Too many requests")
    dq.append(now)


def _extract_first_json_object(text: str) -> dict[str, Any]:
    text = text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    match = re.search(r"\{[\s\S]*\}", text)
    if not match:
        raise ValueError("No JSON object found in model output")
    return json.loads(match.group(0))


async def _call_gemini(prompt: str) -> str:
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Server GEMINI_API_KEY is not configured")

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.2, "topP": 0.9},
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(url, json=body)
    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail=f"Gemini upstream error: {response.text}")
    data = response.json()
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"Unexpected Gemini response format: {exc}") from exc


def _workout_prompt(message: str) -> str:
    return f"""You are FitX workout parser.
Return STRICT JSON only, no markdown.
JSON schema:
{{
  "reply": string,
  "exercise": string|null,
  "sets": number|null,
  "reps": number|null,
  "weight": number|null,
  "rpe": number|null
}}
Rules:
- reply must be concise English.
- If this is not a workout logging message, set exercise/sets/reps/weight/rpe to null.
- If values are unknown, use null.
User message:
{message}
"""


def _meal_prompt(message: str) -> str:
    return f"""You are FitX nutrition parser.
Return STRICT JSON only, no markdown.
JSON schema:
{{
  "reply": string,
  "name": string|null,
  "calories": number|null,
  "protein": number|null,
  "carbs": number|null,
  "fat": number|null
}}
Rules:
- reply must be concise English.
- If this is not a meal logging message, set nutrition fields to null.
- If values are unknown, use null.
User message:
{message}
"""


def _chat_prompt(message: str) -> str:
    return f"""You are FitX AI coach.
Respond in concise English only.
Be practical and fitness-focused.
User message:
{message}
"""


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/assistant/workout", response_model=WorkoutAssistantAPIResponse)
async def assistant_workout(
    payload: AssistantRequestPayload,
    request: Request,
    x_api_key: str | None = Header(default=None),
) -> WorkoutAssistantAPIResponse:
    _require_auth_if_enabled(x_api_key)
    _enforce_rate_limit(request.client.host if request.client else payload.userId)
    raw = await _call_gemini(_workout_prompt(payload.message))
    parsed = _extract_first_json_object(raw)
    return WorkoutAssistantAPIResponse(
        reply=str(parsed.get("reply", "Logged.")),
        exercise=parsed.get("exercise"),
        sets=parsed.get("sets"),
        reps=parsed.get("reps"),
        weight=parsed.get("weight"),
        rpe=parsed.get("rpe"),
    )


@app.post("/api/assistant/meal", response_model=MealAssistantAPIResponse)
async def assistant_meal(
    payload: AssistantRequestPayload,
    request: Request,
    x_api_key: str | None = Header(default=None),
) -> MealAssistantAPIResponse:
    _require_auth_if_enabled(x_api_key)
    _enforce_rate_limit(request.client.host if request.client else payload.userId)
    raw = await _call_gemini(_meal_prompt(payload.message))
    parsed = _extract_first_json_object(raw)
    return MealAssistantAPIResponse(
        reply=str(parsed.get("reply", "Logged.")),
        name=parsed.get("name"),
        calories=parsed.get("calories"),
        protein=parsed.get("protein"),
        carbs=parsed.get("carbs"),
        fat=parsed.get("fat"),
    )


@app.post("/api/assistant/chat", response_model=ChatAssistantAPIResponse)
async def assistant_chat(
    payload: AssistantRequestPayload,
    request: Request,
    x_api_key: str | None = Header(default=None),
) -> ChatAssistantAPIResponse:
    _require_auth_if_enabled(x_api_key)
    _enforce_rate_limit(request.client.host if request.client else payload.userId)
    raw = await _call_gemini(_chat_prompt(payload.message))
    return ChatAssistantAPIResponse(reply=raw)
