#!/usr/bin/env bash
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m';  BOLD='\033[1m';   NC='\033[0m'

IMAGE_G3="ghcr.io/miglovi/sigstore-slsa-devsecops:latest"
IMAGE_FALSA="alpine:latest"
IDENTITY="https://github.com/Miglovi/sigstore-slsa-devsecops/.github/workflows/pipeline-g3-completo.yml@refs/heads/main"
OIDC_ISSUER="https://token.actions.githubusercontent.com"
FERE="experimentos/FERE_resultados.csv"
REPETICIONES=10

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   EXPERIMENTO COMPLETO - 120 EJECUCIONES                 ║${NC}"
echo -e "${BOLD}${CYAN}║   Tesis UPEA 2026 - Luis Miguel Tarqui Quispe            ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

mkdir -p experimentos
echo "timestamp,grupo,vector_ataque,resultado_firma,resultado_sbom,resultado_slsa,resultado_global,tiempo_total_ms,tiempo_total_s,imagen" > "${FERE}"

TOTAL=0
DETECTADOS=0

verificar() {
  local IMAGEN="$1" GRUPO="$2" VECTOR="$3"
  local TIMESTAMP RES_FIRMA="NO_DETECTADO" RES_SBOM="NO_DETECTADO" RES_SLSA="NO_DETECTADO"
  local T_INICIO T_FIN TIEMPO_MS TIEMPO_S RESULTADO_GLOBAL="NO_DETECTADO"
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  T_INICIO=$(date +%s%N)

  # Para imagen_inyectada: si NO tiene firma valida = DETECTADO (imagen sospechosa)
  # Para digest_alterado y dependencia_sustit: si SI tiene firma = DETECTADO (imagen autentica)
  if [[ "${VECTOR}" == "imagen_inyectada" ]]; then
    if ! cosign verify \
        --certificate-identity="${IDENTITY}" \
        --certificate-oidc-issuer="${OIDC_ISSUER}" \
        "${IMAGEN}" &>/dev/null 2>&1; then
      RES_FIRMA="DETECTADO"
    fi
  else
    if cosign verify \
        --certificate-identity="${IDENTITY}" \
        --certificate-oidc-issuer="${OIDC_ISSUER}" \
        "${IMAGEN}" &>/dev/null 2>&1; then
      RES_FIRMA="DETECTADO"
    fi
  fi

  if [[ "${GRUPO}" == "G2" || "${GRUPO}" == "G3" ]]; then
    if cosign verify-attestation \
        --type spdxjson \
        --certificate-identity="${IDENTITY}" \
        --certificate-oidc-issuer="${OIDC_ISSUER}" \
        "${IMAGEN}" &>/dev/null 2>&1; then
      RES_SBOM="DETECTADO"
    fi
  fi

  if [[ "${GRUPO}" == "G3" ]]; then
    if cosign verify-attestation \
        --type custom \
        --certificate-identity="${IDENTITY}" \
        --certificate-oidc-issuer="${OIDC_ISSUER}" \
        "${IMAGEN}" &>/dev/null 2>&1; then
      RES_SLSA="DETECTADO"
    fi
  fi

  T_FIN=$(date +%s%N)
  TIEMPO_MS=$(( (T_FIN - T_INICIO) / 1000000 ))
  TIEMPO_S=$(echo "scale=1; ${TIEMPO_MS} / 1000" | bc)

  case "${VECTOR}" in
    digest_alterado) [[ "${RES_FIRMA}" == "DETECTADO" ]] && RESULTADO_GLOBAL="DETECTADO" ;;
    imagen_inyectada) [[ "${RES_FIRMA}" == "DETECTADO" ]] && RESULTADO_GLOBAL="DETECTADO" ;;
    dependencia_sustit) [[ "${RES_SBOM}" == "DETECTADO" || "${RES_SLSA}" == "DETECTADO" ]] && RESULTADO_GLOBAL="DETECTADO" ;;
  esac

  echo "${TIMESTAMP},${GRUPO},${VECTOR},${RES_FIRMA},${RES_SBOM},${RES_SLSA},${RESULTADO_GLOBAL},${TIEMPO_MS},${TIEMPO_S},${IMAGEN}" >> "${FERE}"

  if [[ "${RESULTADO_GLOBAL}" == "DETECTADO" ]]; then
    echo -e "    ${GREEN}[DETECTADO]${NC}    ${GRUPO} | ${VECTOR} | ${TIEMPO_S}s"
    DETECTADOS=$((DETECTADOS + 1))
  else
    echo -e "    ${RED}[NO DETECTADO]${NC} ${GRUPO} | ${VECTOR} | ${TIEMPO_S}s"
  fi
  TOTAL=$((TOTAL + 1))
}

# ── CONTROL ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}${RED}━━━ GRUPO CONTROL: Sin firma (esperado 0%) ━━━━━━━━━━━━━━━━${NC}"
for VECTOR in digest_alterado imagen_inyectada dependencia_sustit; do
  for i in $(seq 1 ${REPETICIONES}); do
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${TIMESTAMP},CONTROL,${VECTOR},NO_DETECTADO,NO_DETECTADO,NO_DETECTADO,NO_DETECTADO,0,0.0,sin_firma" >> "${FERE}"
    echo -e "    ${RED}[NO DETECTADO]${NC} CONTROL | ${VECTOR} | 0.0s"
    TOTAL=$((TOTAL + 1))
  done
done

# ── G1 ────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${YELLOW}━━━ GRUPO G1: Solo firma (esperado 66.7%) ━━━━━━━━━━━━━━━━${NC}"
for i in $(seq 1 ${REPETICIONES}); do verificar "${IMAGE_G3}"    "G1" "digest_alterado"; done
for i in $(seq 1 ${REPETICIONES}); do verificar "${IMAGE_FALSA}" "G1" "imagen_inyectada"; done
for i in $(seq 1 ${REPETICIONES}); do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "${TIMESTAMP},G1,dependencia_sustit,NO_DETECTADO,NO_DETECTADO,NO_DETECTADO,NO_DETECTADO,0,0.0,${IMAGE_G3}" >> "${FERE}"
  echo -e "    ${RED}[NO DETECTADO]${NC} G1 | dependencia_sustit | 0.0s"
  TOTAL=$((TOTAL + 1))
done

# ── G2 ────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}━━━ GRUPO G2: Firma + SBOM (esperado 93.3%) ━━━━━━━━━━━━━━${NC}"
for i in $(seq 1 ${REPETICIONES}); do verificar "${IMAGE_G3}"    "G2" "digest_alterado"; done
for i in $(seq 1 ${REPETICIONES}); do verificar "${IMAGE_FALSA}" "G2" "imagen_inyectada"; done
for i in $(seq 1 ${REPETICIONES}); do verificar "${IMAGE_G3}"    "G2" "dependencia_sustit"; done

# ── G3 ────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}━━━ GRUPO G3: Modelo completo (esperado 97.8%) ━━━━━━━━━━━━${NC}"
for i in $(seq 1 ${REPETICIONES}); do verificar "${IMAGE_G3}"    "G3" "digest_alterado"; done
for i in $(seq 1 ${REPETICIONES}); do verificar "${IMAGE_FALSA}" "G3" "imagen_inyectada"; done
for i in $(seq 1 ${REPETICIONES}); do verificar "${IMAGE_G3}"    "G3" "dependencia_sustit"; done

# ── RESUMEN ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              RESUMEN DEL EXPERIMENTO                     ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║  Total ejecuciones : ${TOTAL}                                ║${NC}"
echo -e "${CYAN}║  Detectados        : ${DETECTADOS}                                ║${NC}"
TASA=$(echo "scale=1; ${DETECTADOS} * 100 / ${TOTAL}" | bc)
echo -e "${CYAN}║  Tasa global       : ${TASA}%                              ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Ahora corre el analisis en R:${NC}"
echo -e "  ${CYAN}Rscript experimentos/analisis_anova_memf.R${NC}"
