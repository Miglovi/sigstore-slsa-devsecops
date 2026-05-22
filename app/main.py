from fastapi import FastAPI
from fastapi.responses import JSONResponse
import hashlib, json, os
from datetime import datetime

app = FastAPI(
    title="Artefacto SLSA - Tesis UPEA",
    description="Microservicio firmado con Sigstore/Cosign bajo marco SLSA Level 2",
    version="1.0.0",
)

BUILD_INFO = {
    "version":    os.getenv("APP_VERSION", "1.0.0"),
    "build_date": os.getenv("BUILD_DATE",  datetime.utcnow().isoformat()),
    "commit_sha": os.getenv("GITHUB_SHA",  "local"),
    "signed_by":  "Sigstore/Cosign keyless",
    "slsa_level": "SLSA Level 2",
    "author":     "Luis Miguel Tarqui Quispe - UPEA 2026",
}

@app.get("/")
def root():
    return {"message": "Artefacto firmado con Sigstore", "status": "running", "build": BUILD_INFO}

@app.get("/health")
def health():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/verify")
def verify():
    payload = json.dumps(BUILD_INFO, sort_keys=True).encode()
    digest  = hashlib.sha256(payload).hexdigest()
    return JSONResponse(content={
        "artifact_digest": f"sha256:{digest}",
        "transparency_log": "https://rekor.sigstore.dev",
        "build_info": BUILD_INFO,
    })
