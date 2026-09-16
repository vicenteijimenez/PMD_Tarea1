#!/usr/bin/env bash
set -e

mkdir -p resultados

echo "=== Compilando implementaciones en C ==="
gcc -O3 aligner_seq.c -o aligner_seq
gcc -O3 -pthread aligner_pthreads.c -o aligner_pthreads
echo "Compilación exitosa."

# Archivos oficiales de la tarea
FASTQ="data/EC.50X.R1.fastq.gz"
FASTA="data/ecoli-k12-ref.fna"
K=15
L=10
M=4641652
C=1
THREADS=4
X=1000
Y=64

TIME_FORMAT="\nTiempo real: %E | CPU: %P | RAM pico: %M KB"

echo -e "\n========================================================"
echo " [1/3] AWK Secuencial (400k líneas / 100k reads)"
echo "========================================================"
/usr/bin/time -f "$TIME_FORMAT" \
bash -c "gzip -dc '$FASTQ' | head -n 400000 | awk -v k=$K -v L=$L -v M=$M -v c=$C -f aligner.awk '$FASTA' - > resultados/resultados_awk.tsv"

echo -e "\n========================================================"
echo " [2/3] C Secuencial (400k líneas / 100k reads)"
echo "========================================================"
/usr/bin/time -f "$TIME_FORMAT" \
bash -c "gzip -dc '$FASTQ' | head -n 400000 | ./aligner_seq '$FASTA' $K $L $M $C > resultados/resultados_c.tsv"

echo -e "\n========================================================"
echo " [3/3] C Pthreads ($THREADS hilos, 400k líneas / 100k reads)"
echo "========================================================"
/usr/bin/time -f "$TIME_FORMAT" \
bash -c "gzip -dc '$FASTQ' | head -n 400000 | ./aligner_pthreads '$FASTA' $K $L $M $C $THREADS $X $Y > resultados/resultados_threads.tsv"

echo -e "\n========================================================"
echo " Verificación de Coincidencia (Apartado 2d)"
echo "========================================================"
diff -s resultados/resultados_awk.tsv resultados/resultados_c.tsv
diff -s resultados/resultados_c.tsv resultados/resultados_threads.tsv

echo -e "\nPrueba completada con éxito. Las 3 versiones coinciden idénticamente."
