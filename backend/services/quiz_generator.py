import os
import json
import re
import time
import uuid
import logging
from typing import Optional

from google import genai

logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
log = logging.getLogger(__name__)


class LiveQuizGenerator:
    # Try models in order — first one that works will be used
    MODELS = [
        "models/gemini-2.0-flash",
        "models/gemini-2.0-flash-lite",
        "models/gemini-2.5-flash",
        "models/gemini-flash-latest",
        "models/gemini-flash-lite-latest",
    ]

    def __init__(self, api_key: Optional[str] = None):
        key = api_key or os.getenv("GEMINI_API_KEY")
        if not key:
            raise ValueError("Set GEMINI_API_KEY env var or pass api_key= to LiveQuizGenerator()")
        self.client = genai.Client(api_key=key)
        self.model = self.MODELS[0]  # start with first, fallback on error
        log.info(f"LiveQuizGenerator ready — will try models: {self.MODELS}")

    def generate(self, content: str, topic_name: str, count: int = 10) -> list[dict]:
        """Generate `count` fresh MCQ questions from `content`."""
        if not content or not content.strip():
            log.warning("Empty content passed to generator")
            return []

        trimmed = content[:6000]
        prompt = self._build_prompt(trimmed, topic_name, count)

        for model in self.MODELS:
            for attempt in range(2):
                try:
                    log.info(f"Trying model={model}, attempt {attempt + 1}")
                    response = self.client.models.generate_content(
                        model=model,
                        contents=prompt,
                    )
                    questions = self._parse(response.text, count)
                    if questions:
                        log.info(f"Generated {len(questions)} questions with {model}")
                        return questions
                    log.warning("Parsed 0 questions")
                    break  # bad parse, try next model
                except Exception as e:
                    err_str = str(e)
                    log.error(f"Model {model} attempt {attempt + 1}: {e}")
                    if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                        # Quota hit on this model — skip to next model immediately
                        log.info(f"Quota exhausted for {model}, trying next model...")
                        break
                    elif "404" in err_str or "NOT_FOUND" in err_str:
                        # Model not available — skip to next
                        log.info(f"Model {model} not available, trying next...")
                        break
                    elif attempt == 0:
                        time.sleep(3)

        log.error("All models failed — returning empty list")
        return []

        log.error("All attempts failed — returning empty list")
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
        clean = raw.strip()
        clean = re.sub(r"^```(?:json)?\s*\n?", "", clean)
        clean = re.sub(r"\n?```\s*$", "", clean)
        clean = clean.strip()

        match = re.search(r"\[.*\]", clean, re.DOTALL)
        if not match:
            log.error(f"No JSON array found in response: {raw[:200]}")
            return []

        try:
            data = json.loads(match.group(0))
        except json.JSONDecodeError as e:
            log.error(f"JSON parse error: {e}")
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


# Keep old name as alias for any existing imports
QuizGenerator = LiveQuizGenerator
