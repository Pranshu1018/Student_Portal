import os
import json
import re
import time
import uuid
import logging
from typing import Optional

import requests

logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
log = logging.getLogger(__name__)

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

MODELS = [
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant",
    "mixtral-8x7b-32768",
]


class LiveQuizGenerator:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("GROQ_API_KEY")
        if not self.api_key:
            raise ValueError("Set GROQ_API_KEY env var or pass api_key= to LiveQuizGenerator()")
        log.info("LiveQuizGenerator ready (Groq)")

    def generate(self, content: str, topic_name: str, count: int = 10) -> list[dict]:
        if not content or not content.strip():
            log.warning("Empty content passed to generator")
            return []

        trimmed = content[:6000]
        prompt = self._build_prompt(trimmed, topic_name, count)

        for model in MODELS:
            for attempt in range(2):
                try:
                    log.info(f"Trying model={model}, attempt {attempt + 1}")
                    response = requests.post(
                        GROQ_API_URL,
                        headers={
                            "Authorization": f"Bearer {self.api_key}",
                            "Content-Type": "application/json",
                        },
                        json={
                            "model": model,
                            "messages": [{"role": "user", "content": prompt}],
                            "temperature": 0.7,
                            "max_tokens": 4096,
                        },
                        timeout=60,
                    )
                    response.raise_for_status()
                    text = response.json()["choices"][0]["message"]["content"]
                    questions = self._parse(text, count)
                    if questions:
                        log.info(f"Generated {len(questions)} questions with {model}")
                        return questions
                    log.warning("Parsed 0 questions, trying next model")
                    break
                except requests.HTTPError as e:
                    status = e.response.status_code if e.response else 0
                    log.error(f"Model {model} attempt {attempt + 1}: HTTP {status} — {e}")
                    if status in (429, 503):
                        log.info(f"Rate limited on {model}, trying next...")
                        break
                    elif attempt == 0:
                        time.sleep(3)
                except Exception as e:
                    log.error(f"Model {model} attempt {attempt + 1}: {e}")
                    if attempt == 0:
                        time.sleep(2)

        log.error("All models failed")
        return []

    def _build_prompt(self, content: str, topic_name: str, count: int) -> str:
        easy   = max(1, count // 3)
        hard   = max(1, count // 3)
        medium = count - easy - hard
        return f"""You are an expert computer science educator.
Generate exactly {count} multiple choice questions based on the content below about "{topic_name}".

DIFFICULTY MIX:
- {easy} easy questions (basic recall, definitions)
- {medium} medium questions (application, understanding)
- {hard} hard questions (analysis, edge cases, complexity)

STRICT RULES:
1. Every question must be directly answerable from the content
2. All 4 options must be plausible — no obviously wrong answers
3. Correct answer must be unambiguously correct
4. No two questions should test the same concept
5. Explanation must say WHY the answer is correct (1-2 sentences)

CONTENT:
\"\"\"{content}\"\"\"

OUTPUT FORMAT:
Return ONLY a raw JSON array. No markdown fences. No text before or after.
Each element must have exactly these keys:
question, option_a, option_b, option_c, option_d,
correct_answer (exactly "A" or "B" or "C" or "D"),
difficulty (exactly "easy" or "medium" or "hard"),
explanation

Now generate all {count} questions as a JSON array:"""

    def _parse(self, raw: str, expected_count: int) -> list[dict]:
        clean = raw.strip().lstrip("\ufeff\u200b\u200c\u200d")
        clean = re.sub(r"^```(?:json)?\s*\n?", "", clean)
        clean = re.sub(r"\n?```\s*$", "", clean)
        clean = clean.strip()

        match = re.search(r"\[[\s\S]*\]", clean)
        if not match:
            log.error(f"No JSON array found in response: {raw[:200]}")
            return []

        json_str = match.group(0)
        json_str = re.sub(r",\s*([\]}])", r"\1", json_str)

        try:
            data = json.loads(json_str)
        except json.JSONDecodeError as e:
            log.warning(f"JSON parse error ({e}), attempting repair...")
            try:
                repaired = re.sub(r"(?<![\\])'", '"', json_str)
                data = json.loads(repaired)
            except json.JSONDecodeError as e2:
                log.error(f"JSON repair failed: {e2}\nRaw snippet: {json_str[:400]}")
                return []

        if not isinstance(data, list):
            return []

        questions = []
        for i, item in enumerate(data):
            try:
                answer = str(item.get("correct_answer", "A")).upper().strip()
                if answer not in ("A", "B", "C", "D"):
                    answer = "A"
                difficulty = str(item.get("difficulty", "medium")).lower().strip()
                if difficulty not in ("easy", "medium", "hard"):
                    difficulty = "medium"
                q = {
                    "quizId":        str(uuid.uuid4()),
                    "question":      str(item.get("question", "")).strip(),
                    "optionA":       str(item.get("option_a", "")).strip(),
                    "optionB":       str(item.get("option_b", "")).strip(),
                    "optionC":       str(item.get("option_c", "")).strip(),
                    "optionD":       str(item.get("option_d", "")).strip(),
                    "correctAnswer": answer,
                    "difficulty":    difficulty,
                    "explanation":   str(item.get("explanation", "")).strip(),
                }
                required = ["question", "optionA", "optionB", "optionC", "optionD"]
                if all(q[k] for k in required):
                    questions.append(q)
                else:
                    log.warning(f"Skipping incomplete question {i + 1}")
            except Exception as e:
                log.warning(f"Skipping question {i + 1}: {e}")

        return questions


QuizGenerator = LiveQuizGenerator
