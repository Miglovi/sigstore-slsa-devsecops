FROM python:3.12-slim AS builder
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim AS runtime
LABEL org.opencontainers.image.title="Artefacto SLSA - Tesis UPEA"
LABEL org.opencontainers.image.authors="Luis Miguel Tarqui Quispe"
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/main.py .
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser
EXPOSE 8000
ARG BUILD_DATE
ARG GITHUB_SHA
ENV BUILD_DATE=${BUILD_DATE}
ENV GITHUB_SHA=${GITHUB_SHA}
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
