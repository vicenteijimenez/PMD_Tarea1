#!/usr/bin/env bash
set -e

mkdir -p resultados tests

ECOLI_FASTA="data/ecoli-k12-ref.fna"
ECOLI_FASTQ="data/EC.50X.R1.fastq.gz"
K=15
L=10
M=4641652
C=1
X=1000
Y=64

TIME_FMT="Tiempo: %E | CPU: %P | RAM: %M KB"

echo "=========================================================="
echo " 1. AWK Secuencial (100.000 lecturas)"
echo "=========================================================="
/usr/bin/time -f "$TIME_FMT" \
awk -v k=$K -v L=$L -v M=$M -v c=$C -f aligner.awk "$ECOLI_FASTA" <(gzip -dc "$ECOLI_FASTQ" | head -n 400000) > resultados/ecoli_awk.tsv

echo -e "\n=========================================================="
echo " 2. C Secuencial (100.000 lecturas)"
echo "=========================================================="
/usr/bin/time -f "$TIME_FMT" \
./aligner_seq "$ECOLI_FASTA" $K $L $M $C < <(gzip -dc "$ECOLI_FASTQ" | head -n 400000) > resultados/ecoli_c_seq.tsv

for THREADS in 1 2 4 8; do
    echo -e "\n=========================================================="
    echo " 3. C Pthreads - $THREADS hilos (100.000 lecturas)"
    echo "=========================================================="
    /usr/bin/time -f "$TIME_FMT" \
    ./aligner_pthreads "$ECOLI_FASTA" $K $L $M $C $THREADS $X $Y < <(gzip -dc "$ECOLI_FASTQ" | head -n 400000) > resultados/ecoli_pthreads_${THREADS}.tsv
done

echo -e "\n=========================================================="
echo " 4. Distribución de Aciertos y Scores (Base: C Secuencial)"
echo "=========================================================="
awk -f tests/stats.awk resultados/ecoli_c_seq.tsv
