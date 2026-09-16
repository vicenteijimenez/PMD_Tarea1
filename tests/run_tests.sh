#!/usr/bin/env bash
set -e

mkdir -p resultados tests

echo "========================================================"
echo " [PASO 0] Compilando con -O3"
echo "========================================================"
gcc -O3 aligner_seq.c -o aligner_seq
gcc -O3 -pthread aligner_pthreads.c -o aligner_pthreads
echo "Compilacion exitosa."

ECOLI_FASTA="data/ecoli-k12-ref.fna"
ECOLI_FASTQ="data/EC.50X.R1.fastq.gz"
K_ECO=15
L_ECO=10
M_ECO=4641652
C_ECO=1
X_VAL=1000
Y_VAL=64

TIME_FMT="Tiempo real: %E | CPU: %P | RAM pico: %M KB"

echo -e "\n========================================================"
echo " [TEST 1] E. coli - AWK Secuencial (100k reads)"
echo "========================================================"
/usr/bin/time -f "$TIME_FMT" \
awk -v k=$K_ECO -v L=$L_ECO -v M=$M_ECO -v c=$C_ECO -f aligner.awk "$ECOLI_FASTA" <(gzip -dc "$ECOLI_FASTQ" | head -n 400000) > resultados/ecoli_awk.tsv

echo -e "\n========================================================"
echo " [TEST 2] E. coli - C Secuencial (100k reads)"
echo "========================================================"
/usr/bin/time -f "$TIME_FMT" \
./aligner_seq "$ECOLI_FASTA" $K_ECO $L_ECO $M_ECO $C_ECO < <(gzip -dc "$ECOLI_FASTQ" | head -n 400000) > resultados/ecoli_c_seq.tsv

echo -e "\n========================================================"
echo " [TEST 3] E. coli - C Pthreads (1, 2, 4, 8 hilos, 100k reads)"
echo "========================================================"
for THREADS in 1 2 4 8; do
    echo -e "\n--> C Pthreads ($THREADS hilos):"
    /usr/bin/time -f "$TIME_FMT" \
    ./aligner_pthreads "$ECOLI_FASTA" $K_ECO $L_ECO $M_ECO $C_ECO $THREADS $X_VAL $Y_VAL < <(gzip -dc "$ECOLI_FASTQ" | head -n 400000) > resultados/ecoli_pthreads_${THREADS}.tsv
done

echo -e "\n========================================================"
echo " [VALIDACION] Coincidencia de Salidas"
echo "========================================================"
check_diff() {
    if cmp -s "$1" "$2"; then
        echo "diff: False (Archivos $1 y $2 son IDENTICOS)"
    else
        echo "diff: True  (Archivos $1 y $2 TIENEN DIFERENCIAS)"
    fi
}

check_diff resultados/ecoli_awk.tsv resultados/ecoli_c_seq.tsv
check_diff resultados/ecoli_c_seq.tsv resultados/ecoli_pthreads_1.tsv
check_diff resultados/ecoli_c_seq.tsv resultados/ecoli_pthreads_2.tsv
check_diff resultados/ecoli_c_seq.tsv resultados/ecoli_pthreads_4.tsv
check_diff resultados/ecoli_c_seq.tsv resultados/ecoli_pthreads_8.tsv

echo -e "\n========================================================"
echo " [METRICAS] Aciertos y Distribucion de Scores (E. coli)"
echo "========================================================"
awk -f tests/stats.awk resultados/ecoli_c_seq.tsv

# Evaluacion Humano si existen los datos de prueba
HUMAN_FASTA="data/GRCh38_test_small.fna"
HUMAN_FASTQ="data/sample_1000.fq"
if [ -f "$HUMAN_FASTA" ] && [ -f "$HUMAN_FASTQ" ]; then
    echo -e "\n========================================================"
    echo " [TEST 4] Humano (Muestra) - C Secuencial"
    echo "========================================================"
    /usr/bin/time -f "$TIME_FMT" \
    ./aligner_seq "$HUMAN_FASTA" 31 10 1000000 1 < "$HUMAN_FASTQ" > resultados/humano_c_seq.tsv

    echo -e "\n========================================================"
    echo " [TEST 5] Humano (Muestra) - C Pthreads (4 hilos)"
    echo "========================================================"
    /usr/bin/time -f "$TIME_FMT" \
    ./aligner_pthreads "$HUMAN_FASTA" 31 10 1000000 1 4 100 16 < "$HUMAN_FASTQ" > resultados/humano_pthreads_4.tsv

    echo -e "\n[VALIDACION HUMANO]"
    check_diff resultados/humano_c_seq.tsv resultados/humano_pthreads_4.tsv
    awk -f tests/stats.awk resultados/humano_c_seq.tsv
fi

echo -e "\n--- Fin del benchmark ---"
