import io
import os
import secrets
import sys
import tempfile
from pathlib import Path

_MISSING_DEPS_MSG = """
============================================================
 ❌ Missing dependencies!
============================================================
 Run any ONE of these commands inside the project folder:

  Option 1 (uv - fastest):
    uv sync

  Option 2 (pip + venv):
    python -m venv .venv
    .venv\\Scripts\\Activate.ps1        (PowerShell)
    OR  .venv\\Scripts\\activate.bat    (CMD)
    python -m pip install -r requirements.txt
============================================================
"""

try:
    import cadquery as cq
    import cv2
    import numpy as np
    from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
    from fastapi.responses import StreamingResponse
    from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
    from rembg import remove
except ImportError as _e:
    print(_MISSING_DEPS_MSG)
    print(f"Original error: {_e}")
    sys.exit(1)

try:
    from dotenv import load_dotenv
    _HAS_DOTENV = True
except ImportError:
    _HAS_DOTENV = False


_PROJECT_DIR = Path(__file__).resolve().parent
_ENV_FILE = _PROJECT_DIR / ".env"
if _HAS_DOTENV and _ENV_FILE.exists():
    load_dotenv(dotenv_path=_ENV_FILE)


def _is_railway_deploy() -> bool:
    """Detect Railway / managed deployment (Railway sets RAILWAY_ENVIRONMENT_NAME,
    RAILWAY_PROJECT_ID, RAILWAY_SERVICE_ID, or injects PORT on bind-port env)."""
    markers = (
        "RAILWAY_ENVIRONMENT_NAME",
        "RAILWAY_PROJECT_ID",
        "RAILWAY_SERVICE_ID",
        "RAILWAY_PUBLIC_DOMAIN",
        "RAILWAY_DEPLOYMENT_ID",
    )
    if any(os.getenv(m) for m in markers):
        return True
    # Best-effort fallback: Railway always injects PORT env on a non-ephemeral deploy.
    port = os.getenv("PORT")
    if port and port != "8000":
        return True
    return False


_IS_RAILWAY = _is_railway_deploy()


app = FastAPI(title="CAD Backend - Image to STEP API", version="1.0.0")
security = HTTPBearer(auto_error=False)


def _ensure_key_persisted() -> str:
    """Return CAD_BACKEND_KEY.

    - On Railway (ephemeral FS + multi-instance):
        * MUST be provided via Railway Service Variables.
        * If missing, log a CRITICAL error and exit (auto-generated keys
          cannot be shared with the client frontend and are lost on restart).
    - Otherwise (local/dev):
        * Honor existing env value, else generate a secure one and persist to .env.
    """
    existing = os.getenv("CAD_BACKEND_KEY")
    if existing:
        return existing.strip()

    if _IS_RAILWAY:
        print("=" * 60)
        print("❌  CRITICAL: CAD_BACKEND_KEY is NOT configured on Railway.")
        print("=" * 60)
        print(" Railway's filesystem is EPHEMERAL — auto-generating a key here would:")
        print("   • Change on every restart / deploy (breaking client-side Bearer auth).")
        print("   • Differ between horizontal replicas (replicas reject each other).")
        print()
        print(" Fix — Go to Railway Dashboard → this Service → Variables:")
        print("   1. Add new variable  CAD_BACKEND_KEY")
        print("   2. Set it to a long random value, e.g.:")
        import secrets as _s
        sample = _s.token_urlsafe(32)
        print(f'        {sample}')
        print("   3. Redeploy.")
        print("   4. Configure your widget / website backend to use the same key.")
        print("=" * 60)
        sys.exit(2)

    new_key = secrets.token_urlsafe(32)
    try:
        if not _ENV_FILE.exists():
            _ENV_FILE.write_text(f"CAD_BACKEND_KEY={new_key}\n", encoding="utf-8")
        else:
            current = _ENV_FILE.read_text(encoding="utf-8")
            if "CAD_BACKEND_KEY" in current:
                import re
                current = re.sub(
                    r"^CAD_BACKEND_KEY\s*=.*$",
                    f"CAD_BACKEND_KEY={new_key}",
                    current,
                    flags=re.MULTILINE,
                )
            else:
                if current and not current.endswith("\n"):
                    current += "\n"
                current += f"CAD_BACKEND_KEY={new_key}\n"
            _ENV_FILE.write_text(current, encoding="utf-8")
    except OSError:
        pass

    print("=" * 60)
    print("🔑  CAD_BACKEND_KEY auto-generated and saved to .env:")
    print(f"    {new_key}")
    print(f"    .env file: {_ENV_FILE}")
    print("ℹ️   Share this key with your client backend (CAD_BACKEND_KEY secret).")
    print("=" * 60)
    return new_key


CAD_BACKEND_KEY: str = _ensure_key_persisted()


def verify_api_key(credentials: HTTPAuthorizationCredentials | None = Depends(security)) -> str:
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=401,
            detail="Missing 'Authorization: Bearer <CAD_BACKEND_KEY>' header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not secrets.compare_digest(credentials.credentials, CAD_BACKEND_KEY):
        raise HTTPException(status_code=401, detail="Invalid CAD_BACKEND_KEY")
    return credentials.credentials


def extract_contour(image: np.ndarray, clearance: int) -> np.ndarray:
    if image.ndim != 3 or image.shape[2] < 4:
        raise ValueError("Expected BGRA image with alpha channel (background removal failed).")

    alpha = image[:, :, 3]
    _, binary = cv2.threshold(alpha, 127, 255, cv2.THRESH_BINARY)

    if clearance > 0:
        kernel_size = int(clearance * 2 + 1)
        kernel = cv2.getStructuringElement(
            cv2.MORPH_ELLIPSE, (kernel_size, kernel_size)
        )
        binary = cv2.dilate(binary, kernel, iterations=1)

    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        raise ValueError("No contour found in the provided image.")
    return max(contours, key=cv2.contourArea)


def create_3d(contour: np.ndarray, height: int) -> cq.Workplane:
    points = contour.squeeze()
    if points.ndim != 2 or points.shape[1] != 2:
        raise ValueError("Invalid contour geometry (expected Nx2 array).")
    if len(points) < 3:
        raise ValueError("Contour too small (<3 points) to create 3D solid.")

    cq_points = [(float(p[0]), float(p[1])) for p in points]
    return cq.Workplane("XY").polyline(cq_points).close().extrude(height)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "cad-backend",
        "key_configured": len(CAD_BACKEND_KEY) > 0,
    }


@app.post("/api/v1/convert/image-to-step")
async def convert_image_to_step(
    image: UploadFile = File(..., description="Input image file (PNG/JPG)"),
    height: int = Form(default=10, ge=1, le=500, description="Extrusion height in mm"),
    clearance: int = Form(default=5, ge=0, le=200, description="Clearance dilation in px"),
    _: str = Depends(verify_api_key),
):
    if not image.filename:
        raise HTTPException(status_code=400, detail="Image filename missing.")

    allowed_exts = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
    if Path(image.filename).suffix.lower() not in allowed_exts:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image format. Allowed: {sorted(allowed_exts)}",
        )

    raw_bytes = await image.read()
    if not raw_bytes:
        raise HTTPException(status_code=400, detail="Empty image file.")
    if len(raw_bytes) > 50 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image too large (max 50 MB).")

    try:
        nparr = np.frombuffer(raw_bytes, np.uint8)
        input_image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if input_image is None:
            raise HTTPException(status_code=400, detail="Could not decode image.")

        bg_removed: np.ndarray = remove(input_image)
        contour = extract_contour(bg_removed, clearance)
        model = create_3d(contour, height)

        with tempfile.TemporaryDirectory() as tmpdir:
            out_path = Path(tmpdir) / "output.step"
            cq.exporters.export(
                model, str(out_path), exportType=cq.exporters.ExportTypes.STEP
            )
            step_bytes = out_path.read_bytes()

        filename = Path(image.filename).stem + ".step"
        return StreamingResponse(
            io.BytesIO(step_bytes),
            media_type="application/step",
            headers={
                "Content-Disposition": f"attachment; filename=\"{filename}\""
            },
        )
    except HTTPException:
        raise
    except ValueError as ve:
        raise HTTPException(status_code=422, detail=str(ve))
    except Exception as e:  # pragma: no cover - defensive
        raise HTTPException(status_code=500, detail=f"Conversion failed: {e}")


if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "0.0.0.0")
    try:
        port = int(os.getenv("PORT", "8000"))
    except (TypeError, ValueError):
        port = 8000
    uvicorn.run(
        "cad_backend:app",
        host=host,
        port=port,
        reload=not _IS_RAILWAY,
        workers=1,
        proxy_headers=True,
        forwarded_allow_ips="*",
        timeout_keep_alive=300,
    )
