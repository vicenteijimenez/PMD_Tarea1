#!/usr/bin/env bash
set -e

mkdir -p resultados

# 1. Descomprimir referencia si aún no está lista
if [ ! -f "data/GRCh38_ref.fna" ]; then
    echo "Descomprimiendo referencia humana GRCh38..."
    gzip -dc data/GCA_000001405.15_GRCh38_full_analysis_set.fna.gz > data/GRCh38_ref.fna
fi

# 2. Extraer muestra reproducible de 100k lecturas si no existe
FASTQ_SAMPLE="data/HG002_sample100k.fq.gz"
if [ ! -f "$FASTQ_SAMPLE" ]; then
    echo "Extrayendo muestra reproducible de 100.000 lecturas (400k líneas)..."
    gzip -dc data/HG002-MGISEQ-L03-1.fq.gz | head -n 400000 | gzip > "$FASTQ_SAMPLE"
fi

FASTA="data/GRCh38_ref.fna"
K=31
L=10
# M ~ 200 millones de celdas (~3.2 GB RAM, cabe en memoria estándar)
M=200000000
C=1
X=1000
Y=64

TIME_FORMAT="Tiempo real: %E | CPU: %P | RAM pico: %M KB"

echo -e "\n========================================================"
echo " [1] C Secuencial - Humano (k=$K, L=$L, M=$M)"
echo "========================================================"
/usr/bin/time -f "$TIME_FORMAT" \
bash -c "gzip -dc '$FASTQ_SAMPLE' | ./aligner_seq '$FASTA' $K $L $M $C > resultados/humano_c_seq.tsv"

echo -e "\n========================================================"
echo " [2] C Pthreads - Humano (4 Hilos)"
echo "========================================================"
/usr/bin/time -f "$TIME_FORMAT" \
bash -c "gzip -dc '$FASTQ_SAMPLE' | ./aligner_pthreads '$FASTA' $K $L $M $C 4 $X $Y > resultados/humano_threads_4.tsv"

echo -e "\n========================================================"
echo " [3] C Pthreads - Humano (8 Hilos)"
echo "========================================================"
/usr/bin/time -f "$TIME_FORMAT" \
bash -c "gzip -dc '$FASTQ_SAMPLE' | ./aligner_pthreads '$FASTA' $K $L $M $C 8 $X $Y > resultados/humano_threads_8.tsv"

echo -e "\n========================================================"
echo " Verificación de Coincidencia Numérica"
echo "========================================================"
diff -s resultados/humano_c_seq.tsv resultados/humano_threads_4.tsv
diff -s resultados/humano_threads_4.tsv resultados/humano_threads_8.tsv

echo -e "\n========================================================"
echo " Distribución de Puntajes (C Secuencial)"
echo "========================================================"
awk 'NR>1 {scores[$5]++} END {for (s in scores) printf "Score %s: %d lecturas\n", s, scores[s]}' resultados/humano_c_seq.tsv | sort -n -k2
