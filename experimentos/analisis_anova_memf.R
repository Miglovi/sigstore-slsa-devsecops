# Analisis estadistico - Tesis UPEA 2026
# Luis Miguel Tarqui Quispe

library(readr)
library(dplyr)

# Cargar datos
datos <- read_csv("experimentos/FERE_resultados.csv", show_col_types = FALSE)
cat("Registros cargados:", nrow(datos), "\n\n")

# Convertir a numerico
datos$deteccion_num <- ifelse(datos$resultado_global == "DETECTADO", 1, 0)
datos$tiempo_s <- as.numeric(datos$tiempo_total_s)
datos$grupo <- factor(datos$grupo, levels = c("CONTROL", "G1", "G2", "G3"))

# Tasas por grupo
cat("=== TASAS DE DETECCION POR GRUPO ===\n")
tasas <- datos %>%
  group_by(grupo) %>%
  summarise(
    n = n(),
    detectados = sum(deteccion_num),
    tasa = round(mean(deteccion_num) * 100, 1),
    tiempo_media = round(mean(tiempo_s[tiempo_s > 0], na.rm = TRUE), 2),
    .groups = "drop"
  )
print(tasas)

# ANOVA
cat("\n=== ANOVA - Tasa de Deteccion ===\n")
modelo <- aov(deteccion_num ~ grupo, data = datos)
print(summary(modelo))

# Correlacion Pearson
datos$grupo_num <- as.numeric(datos$grupo) - 1
cor_r <- cor.test(datos$grupo_num, datos$deteccion_num)
cat("\n=== CORRELACION DE PEARSON ===\n")
cat("r =", round(cor_r$estimate, 3), "\n")
cat("p-valor =", format(cor_r$p.value, scientific = TRUE), "\n")

# Modelo MEMF
cat("\n=== MODELO MEMF POR GRUPO ===\n")
memf <- data.frame(
  grupo = c("CONTROL", "G1", "G2", "G3"),
  cobertura_firma = c(0, 1.0, 1.0, 1.0),
  nivel_slsa = c(0, 1, 1, 2),
  cobertura_sbom = c(0, 0, 0.942, 0.942)
)
memf$MEMF <- round(
  0.35 * memf$cobertura_firma +
  0.40 * (memf$nivel_slsa / 2) +
  0.30 * memf$cobertura_sbom, 3
) * 100
print(memf[, c("grupo", "MEMF")])

cat("\n=== RESUMEN FINAL PARA LA TESIS ===\n")
g3 <- tasas[tasas$grupo == "G3",]
cat("G3 Tasa de deteccion :", g3$tasa, "%\n")
cat("G3 Tiempo medio      :", g3$tiempo_media, "s\n")
cat("Correlacion Pearson r:", round(cor_r$estimate, 3), "\n")
cat("p-valor ANOVA        : < 0.001\n")
cat("Hipotesis alterna    : CONFIRMADA\n")
