web: python -m uvicorn cad_backend:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1 --proxy-headers --forwarded-allow-ips="*" --timeout-keep-alive 300 --timeout-graceful-shutdown 30
