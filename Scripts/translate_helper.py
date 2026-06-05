#!/usr/bin/env python3
"""Translate segments using translatepy with parallel execution for speed."""

import json
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

LANG_MAP = {
    "en": "english", "zh": "chinese", "ja": "japanese",
    "ko": "korean", "fr": "french", "de": "german",
    "es": "spanish", "pt": "portuguese", "it": "italian",
    "ru": "russian", "ar": "arabic", "vi": "vietnamese",
    "th": "thai", "hi": "hindi",
}


def main():
    raw_input = sys.stdin.buffer.read()
    input_data = json.loads(raw_input.decode("utf-8"))
    segments = input_data["segments"]
    source_lang = input_data.get("source_lang", "en")
    target_lang = input_data.get("target_lang", "zh")

    try:
        from translatepy import Translator
        t = Translator()
    except ImportError:
        print(json.dumps({"error": "translatepy not installed"}), file=sys.stderr)
        sys.exit(1)

    source_name = LANG_MAP.get(source_lang, source_lang)
    target_name = LANG_MAP.get(target_lang, target_lang)

    # Translate in parallel using thread pool
    results = [None] * len(segments)

    def translate_one(item):
        idx, text = item
        try:
            result = t.translate(text, destination_language=target_name, source_language=source_name)
            return idx, str(result)
        except Exception as e:
            return idx, f"[翻译失败: {e}]"

    # Use up to 8 parallel threads
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(translate_one, (i, seg["text"])) for i, seg in enumerate(segments)]
        for future in as_completed(futures):
            idx, translated = future.result()
            results[idx] = {
                "index": idx,
                "source_text": segments[idx]["text"],
                "translated_text": translated,
            }

    output = {"segments": results}
    sys.stdout.write(json.dumps(output, ensure_ascii=False))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
