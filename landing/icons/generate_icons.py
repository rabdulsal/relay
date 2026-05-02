#!/usr/bin/env python3
"""
Generate 3 icon concepts for Relay (shared task board / external working memory for AI agents)
using the Gemini API. Tries gemini-2.0-flash-preview-image-generation first, then
imagen-3.0-generate-002, and finally writes prompts.md as a fallback.
"""

import os
import sys
import json
import base64
import urllib.request
import urllib.error
import urllib.parse

API_KEY = "AIzaSyCF5zFAS9XNC4OXSULCgb3NW5dwvX8i874"
OUTPUT_DIR = "/Users/abdulsar/Desktop/Project_Apps/Relay/landing/icons"

PROMPTS = [
    {
        "filename": "icon-v1.png",
        "label": "Relay baton / hand-off",
        "prompt": (
            "App icon, flat minimal design, square canvas 512x512, dark background #06090f. "
            "Two abstract geometric hands or rounded arrow shapes passing a glowing baton/bar between them, "
            "rendered in violet-indigo (#7c6bff). Clean single-color accent on dark. "
            "No text, no fine detail, readable at 16px. Technical, not corporate. "
            "Transparent or very dark background."
        ),
    },
    {
        "filename": "icon-v2.png",
        "label": "Loop / cycle with nodes",
        "prompt": (
            "App icon, flat minimal design, square canvas 512x512, dark background #06090f. "
            "A circular loop or orbit path connecting 3 small rounded square nodes, "
            "arrows showing clockwise flow, rendered in violet-indigo (#7c6bff). "
            "Suggests AI agents passing tasks around a shared board. "
            "No text, no fine detail, works at 16px favicon size. Clean, minimal, technical."
        ),
    },
    {
        "filename": "icon-v3.png",
        "label": "Signal / broadcast memory",
        "prompt": (
            "App icon, flat minimal design, square canvas 512x512, dark background #06090f. "
            "A central rounded square (the task board / memory store) emitting 3 concentric "
            "arc waves outward, like a broadcast or WiFi signal but geometric and sharp-edged. "
            "Violet-indigo accent (#7c6bff) on dark. No text, no gradients, no fine detail. "
            "Readable as a 16px favicon. Feels like external shared memory broadcasting to agents."
        ),
    },
]


def post_json(url, payload):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def try_flash(prompt_text, out_path):
    """Try gemini-2.0-flash-preview-image-generation."""
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"gemini-2.0-flash-preview-image-generation:generateContent?key={API_KEY}"
    )
    payload = {
        "contents": [{"parts": [{"text": prompt_text}]}],
        "generationConfig": {"responseModalities": ["IMAGE", "TEXT"]},
    }
    resp = post_json(url, payload)
    # Navigate to the image bytes
    parts = resp["candidates"][0]["content"]["parts"]
    for part in parts:
        if "inlineData" in part:
            img_data = base64.b64decode(part["inlineData"]["data"])
            with open(out_path, "wb") as f:
                f.write(img_data)
            return True
    return False


def try_imagen(prompt_text, out_path):
    """Try imagen-3.0-generate-002."""
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"imagen-3.0-generate-002:predict?key={API_KEY}"
    )
    payload = {
        "instances": [{"prompt": prompt_text}],
        "parameters": {"sampleCount": 1},
    }
    resp = post_json(url, payload)
    predictions = resp.get("predictions", [])
    if predictions:
        img_data = base64.b64decode(predictions[0]["bytesBase64Encoded"])
        with open(out_path, "wb") as f:
            f.write(img_data)
        return True
    return False


def write_prompts_md(results):
    md_path = os.path.join(OUTPUT_DIR, "prompts.md")
    lines = [
        "# Relay Icon Prompts\n",
        "API generation failed. Paste these prompts into any image generation tool "
        "(Midjourney, DALL-E 3, Stable Diffusion, etc.).\n",
    ]
    for i, p in enumerate(PROMPTS, 1):
        lines.append(f"\n## Concept {i}: {p['label']} → {p['filename']}\n")
        lines.append(f"```\n{p['prompt']}\n```\n")
    if results:
        lines.append("\n## API Errors\n")
        for r in results:
            lines.append(f"- {r}\n")
    with open(md_path, "w") as f:
        f.writelines(lines)
    print(f"Wrote fallback prompts to {md_path}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    errors = []
    generated = []
    fallback_needed = False

    for concept in PROMPTS:
        out_path = os.path.join(OUTPUT_DIR, concept["filename"])
        print(f"\n--- Generating {concept['filename']} ({concept['label']}) ---")

        success = False

        # 1. Try flash model
        try:
            print("  Trying gemini-2.0-flash-preview-image-generation ...")
            success = try_flash(concept["prompt"], out_path)
            if success:
                size = os.path.getsize(out_path)
                print(f"  Saved {out_path} ({size} bytes) via flash model.")
                generated.append(concept["filename"])
        except Exception as e:
            print(f"  Flash model failed: {e}")
            errors.append(f"{concept['filename']} flash: {e}")

        # 2. Fallback to imagen
        if not success:
            try:
                print("  Trying imagen-3.0-generate-002 ...")
                success = try_imagen(concept["prompt"], out_path)
                if success:
                    size = os.path.getsize(out_path)
                    print(f"  Saved {out_path} ({size} bytes) via imagen model.")
                    generated.append(concept["filename"])
            except Exception as e:
                print(f"  Imagen model failed: {e}")
                errors.append(f"{concept['filename']} imagen: {e}")

        if not success:
            fallback_needed = True
            print(f"  Both models failed for {concept['filename']}.")

    print("\n=== Summary ===")
    if generated:
        print(f"Successfully generated: {generated}")
    if fallback_needed or (len(generated) < len(PROMPTS)):
        write_prompts_md(errors)
        print("Fallback prompts.md written.")
    if not generated and not fallback_needed:
        print("All icons generated successfully.")
    elif not generated:
        print("No icons generated — check prompts.md for manual generation.")
        sys.exit(1)


if __name__ == "__main__":
    main()
