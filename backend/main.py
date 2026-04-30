import json
import os
import re
import time
from collections import defaultdict, deque
from threading import Lock
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
    imageBase64: str | None = None


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
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip()
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
_conversation_history: dict[str, deque[dict[str, str]]] = defaultdict(lambda: deque(maxlen=12))
_conversation_lock = Lock()


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


def _push_history(user_id: str, role: str, content: str) -> None:
    text = content.strip()
    if not text:
        return
    with _conversation_lock:
        _conversation_history[user_id].append({"role": role, "content": text})


def _history_block(user_id: str) -> str:
    with _conversation_lock:
        items = list(_conversation_history[user_id])
    if not items:
        return "No prior context."
    lines: list[str] = []
    for item in items[-8:]:
        lines.append(f'{item["role"]}: {item["content"]}')
    return "\n".join(lines)


async def _call_gemini(prompt: str, image_base64: str | None = None) -> str:
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Server GEMINI_API_KEY is not configured")

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
    parts: list[dict[str, Any]] = [{"text": prompt}]
    if image_base64:
        parts.append(
            {
                "inline_data": {
                    "mime_type": "image/jpeg",
                    "data": image_base64,
                }
            }
        )

    body = {
        "contents": [{"parts": parts}],
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
- If an image is attached, infer nutrition from the image first.
- If an image is attached, you MUST provide estimated integer values for calories, protein, carbs, and fat (do not return null for these fields).
- Use best-effort estimates even when uncertain.
- In reply, include food identification first (what the food likely is), then calorie + macros.
- For nutrition questions ("how many calories", "nutrition facts", "how much protein/carbs/fat"), return all 4 values (calories/protein/carbs/fat) whenever possible.
- If the image is a supplement/non-food product and exact nutrition cannot be read, set calories/protein/carbs/fat to null (do NOT fake 0/0/0/0).
- For supplement questions, include likely fitness benefit (e.g., recovery, performance, protein support) and practical use note.
- If this is not a meal logging message and no image is attached, set nutrition fields to null.
- If values are unknown, use null.
User message:
{message}
"""


def _chat_prompt(message: str) -> str:
    return f"""You are FitX AI coach.
Respond in concise English only.
Be practical and fitness-focused.
Use conversation context to resolve references like "that", "same", "what about 2 pounds", etc.
Be conversational and natural, like a smart supportive friend + coach (not robotic).
For daily conversation, prioritize helpful human-like dialogue over rigid tool-style output.
Keep tone warm, encouraging, and specific. Avoid repetitive template phrases.
If user asks multiple questions, answer ALL of them in one reply with short sections.
If the user asks about a food item or calories/nutrition, ALWAYS return:
- estimated calories
- protein (g)
- carbs (g)
- fat (g)
If quantity is provided (e.g., 2 pounds), scale estimates accordingly.
If user asks fat-loss or muscle-gain timeline:
- explain with simple math using 3500 kcal ~= 1 lb fat (theoretical)
- provide estimated days/weeks range
- mention this is theoretical and real-world varies.
If user asks about supplements:
- give practical supplement suggestions for training goal
- include what each does, when to take, and typical dosage range
- if user asks for brands, provide 3-5 common brand examples
- include direct Amazon search links (https://www.amazon.com/s?k=...) so they can click to buy.
For training-planning flows:
- If user asks "what should I train today", first summarize trainable vs fatigued areas using provided recovery snapshot and ask which area they want to train.
- After the user picks an area, give a concrete plan: 4-6 exercises with sets and reps.
- For back day, design compound pulling movements that cover upper back + lower back + rear neck/trap in one integrated session.
- For legs day, design multi-joint compound lower-body movements as one integrated session.
- Keep structure clear with headings: "Recovery Check", "Recommended Focus", "Plan".
When user asks about a specific movement, include form cues, common mistakes, safer alternatives, and progression tips.
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
    response = WorkoutAssistantAPIResponse(
        reply=str(parsed.get("reply", "Logged.")),
        exercise=parsed.get("exercise"),
        sets=parsed.get("sets"),
        reps=parsed.get("reps"),
        weight=parsed.get("weight"),
        rpe=parsed.get("rpe"),
    )
    _push_history(payload.userId, "user", payload.message)
    _push_history(payload.userId, "assistant", response.reply)
    return response


@app.post("/api/assistant/meal", response_model=MealAssistantAPIResponse)
async def assistant_meal(
    payload: AssistantRequestPayload,
    request: Request,
    x_api_key: str | None = Header(default=None),
) -> MealAssistantAPIResponse:
    _require_auth_if_enabled(x_api_key)
    _enforce_rate_limit(request.client.host if request.client else payload.userId)
    meal_message = payload.message if payload.message.strip() else "Please analyze this meal image and estimate calories/macros."
    prompt = f"""{_meal_prompt(meal_message)}

Recent conversation context:
{_history_block(payload.userId)}
"""
    raw = await _call_gemini(prompt, image_base64=payload.imageBase64)
    parsed = _extract_first_json_object(raw)
    response = MealAssistantAPIResponse(
        reply=str(parsed.get("reply", "Logged.")),
        name=parsed.get("name"),
        calories=parsed.get("calories"),
        protein=parsed.get("protein"),
        carbs=parsed.get("carbs"),
        fat=parsed.get("fat"),
    )
    _push_history(payload.userId, "user", payload.message or "[image meal]")
    _push_history(payload.userId, "assistant", response.reply)
    return response


@app.post("/api/assistant/chat", response_model=ChatAssistantAPIResponse)
async def assistant_chat(
    payload: AssistantRequestPayload,
    request: Request,
    x_api_key: str | None = Header(default=None),
) -> ChatAssistantAPIResponse:
    _require_auth_if_enabled(x_api_key)
    _enforce_rate_limit(request.client.host if request.client else payload.userId)
    prompt = f"""{_chat_prompt(payload.message)}

Recent conversation context:
{_history_block(payload.userId)}
"""
    raw = await _call_gemini(prompt)
    response = ChatAssistantAPIResponse(reply=raw)
    _push_history(payload.userId, "user", payload.message)
    _push_history(payload.userId, "assistant", response.reply)
    return response
