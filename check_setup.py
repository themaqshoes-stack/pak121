"""
Quick setup check — run this first:  python check_setup.py
"""
import importlib
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REQUIRED = [
    ("fastapi", "fastapi"),
    ("uvicorn", "uvicorn"),
    ("dotenv", "python-dotenv"),
    ("multipart", "python-multipart"),
    ("cv2", "opencv-python"),
    ("numpy", "numpy"),
    ("rembg", "rembg"),
    ("cadquery", "cadquery"),
]

print("=" * 60)
print("🔍 CAD Backend Setup Diagnostic")
print("=" * 60)
print(f"Python version : {sys.version}")
print(f"Working dir    : {HERE}")
print(f"Executable     : {sys.executable}")
print()

missing = []
for mod, pkg in REQUIRED:
    try:
        importlib.import_module(mod)
        print(f"  ✅ {pkg:20s}  (import {mod})")
    except Exception as e:
        print(f"  ❌ {pkg:20s}  MISSING: {e}")
        missing.append((mod, pkg))

print()
env_file = HERE / ".env"
if env_file.exists():
    raw = env_file.read_text(encoding="utf-8")
    has_key = any(line.strip().startswith("CAD_BACKEND_KEY=") for line in raw.splitlines())
    print(f"ℹ️   .env file found at {env_file}  —  CAD_BACKEND_KEY present: {has_key}")
else:
    print("ℹ️   .env NOT present — backend will auto-generate CAD_BACKEND_KEY on first run.")

print()
has_uv = shutil.which("uv") is not None
has_py = shutil.which("py") is not None
has_python = shutil.which("python") is not None
print(f"uv found     : {has_uv}")
print(f"py launcher  : {has_py}")
print(f"python.exe   : {has_python}")
print()

if missing:
    print("❌ Some dependencies are missing. Install with:")
    if has_uv:
        print("     uv sync")
    else:
        print(f'     python -m pip install -r "{HERE / "requirements.txt"}"')
    print()
    print("Tip: if 'uv' is missing install it first:")
    print("     powershell -c \"irm https://astral.sh/uv/install.ps1 | iex\"")
    sys.exit(1)
else:
    print("✅ All checks passed. You can start the backend.")
    print("   Next step: run_backend.ps1   (or run_backend.bat)")
    print("   Or manual:  python -m uvicorn cad_backend:app --host 0.0.0.0 --port 8000 --reload")
    print("   Then visit: http://localhost:8000/health    (should say status: ok)")
    sys.exit(0)
