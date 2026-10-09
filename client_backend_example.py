"""
Client Backend - Example usage of CAD Backend API.
Drop this into your client website's backend code (Node.js equivalent shown below too).

Required env vars on CLIENT backend:
  CAD_BACKEND_URL  -> e.g. http://localhost:8000  (or deployed https://cad.yourdomain.com)
  CAD_BACKEND_KEY  -> the same API key configured on CAD backend server

Endpoint:
  POST {CAD_BACKEND_URL}/api/v1/convert/image-to-step
  Headers:
    Authorization: Bearer {CAD_BACKEND_KEY}
  Body (multipart/form-data):
    image:      <file bytes>    (required)
    height:     int             (optional, default 10, range 1-500)
    clearance:  int             (optional, default 5,  range 0-200)
  Response:
    200 -> application/step attachment (.step file bytes)
    401 -> invalid/missing key
    400/422/500 -> error JSON
"""

import os
from pathlib import Path
from typing import Optional

import requests  # pip install requests


def convert_image_to_step_client(
    image_path: str,
    output_path: Optional[str] = None,
    height: int = 10,
    clearance: int = 5,
) -> bytes:
    """Client-side helper to call the CAD backend from your website's backend."""
    cad_url = os.environ["CAD_BACKEND_URL"].rstrip("/")
    cad_key = os.environ["CAD_BACKEND_KEY"]

    with open(image_path, "rb") as f:
        files = {"image": (Path(image_path).name, f, "image/png")}
        data = {"height": str(height), "clearance": str(clearance)}
        headers = {"Authorization": f"Bearer {cad_key}"}

        resp = requests.post(
            f"{cad_url}/api/v1/convert/image-to-step",
            files=files,
            data=data,
            headers=headers,
            timeout=600,
        )

    if resp.status_code != 200:
        raise RuntimeError(f"CAD backend error [{resp.status_code}]: {resp.text}")

    step_bytes = resp.content
    if output_path:
        Path(output_path).write_bytes(step_bytes)
    return step_bytes


if __name__ == "__main__":
    # Example:
    # convert_image_to_step_client("test.png", "out.step", height=15)
    print("Set CAD_BACKEND_URL and CAD_BACKEND_KEY env vars, then call convert_image_to_step_client()")
