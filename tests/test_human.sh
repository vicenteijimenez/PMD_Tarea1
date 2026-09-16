#!/usr/bin/env bash
set -e

mkdir -p resultados
DATA_DIR="data"
OUT_DIR="resultados"

HUMAN_REF="$DATA_DIR/GRCh38_chr21.fna"
HUMAN_FQ="$DATA_DIR/sample_human.fq"

echo "=========================================================="
echo "      EVALUACIÓN EXPERIMENTAL: HOMO SAPIENS (GRCh38)      "
echo "=========================================================="

if [ ! -f "$HUMAN_REF" ] || [ ! -f "$HUMAN_FQ" ]; then
    echo "Error: Faltan archivos requeridos en $DATA_DIR/"
    echo "Ejecute 'make data' para descargarlos y prepararlos."
    exit 1
fi

# Submuestra de 1000 lecturas FASTQ (4000 líneas)
head -n 4000 "$HUMAN_FQ" > "$OUT_DIR/human_sample.fq"

# Parámetros para la prueba humana
K=15
L=10
M=46709983
C=1

echo "Configuración: k=$K, L=$L, M=$M, c=$C"
echo ""

# 1. C Secuencial
echo "--> Ejecutando aligner_seq..."
./aligner_seq "$HUMAN_REF" $K $L $M $C < "$OUT_DIR/human_sample.fq" > "$OUT_DIR/human_seq.tsv"

# 2. C Pthreads (4 hilos)
echo "--> Ejecutando aligner_pthreads (4 hilos, chunk=1000, queue=64)..."
./aligner_pthreads "$HUMAN_REF" $K $L $M $C 4 1000 64 < "$OUT_DIR/human_sample.fq" > "$OUT_DIR/human_pthreads.tsv"

# 3. Validación estricta
echo "--> Verificando equivalencia de salida con cmp..."
if cmp -s "$OUT_DIR/human_seq.tsv" "$OUT_DIR/human_pthreads.tsv"; then
    echo "  ✓ Humano (C seq vs C pthreads): IDENTICOS"
else
    echo "  ✗ Error: Discrepancia encontrada en la salida humana"
    exit 1
fi

# 4. Estadísticas si stats.awk existe
if [ -f "tests/stats.awk" ]; then
    echo ""
    echo "--> Métricas de aciertos y distribución:"
    awk -f tests/stats.awk "$OUT_DIR/human_pthreads.tsv"
fi

echo ""
echo "=========================================================="
echo "        PRUEBA DE GENOMA HUMANO FINALIZADA CON ÉXITO      "
echo "=========================================================="
