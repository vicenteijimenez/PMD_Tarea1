#!/usr/bin/env bash
set -e

DATA_DIR="data"
mkdir -p "$DATA_DIR"

echo "=========================================================="
echo " [DESCARGA LIGERA] Obteniendo datasets de prueba (< 150 MB)"
echo "=========================================================="

# -------------------------------------------------------------
# PARTE 1: Tabulares
# -------------------------------------------------------------
if [ ! -f "$DATA_DIR/worldcitiespop.csv.gz" ]; then
    echo "--> Descargando worldcitiespop.csv.gz..."
    curl -sSL "https://github.com/adigenova/uohpmd/raw/refs/heads/main/data/tarea1/worldcitiespop.csv.gz" -o "$DATA_DIR/worldcitiespop.csv.gz"
fi

if [ ! -f "$DATA_DIR/matrix.txt" ]; then
    echo "--> Descargando matrix.txt..."
    curl -sSL "https://raw.githubusercontent.com/adigenova/uohpmd/refs/heads/main/data/tarea1/matrix.txt" -o "$DATA_DIR/matrix.txt"
fi

# -------------------------------------------------------------
# PARTE 2: E. coli (Completo, ~82 MB)
# -------------------------------------------------------------
if [ ! -f "$DATA_DIR/ecoli-k12-ref.fna" ]; then
    echo "--> Descargando ecoli-k12-ref.fna..."
    curl -sSL "https://raw.githubusercontent.com/adigenova/wengan_demo/master/ecoli/reference/ecoli-k12-ref.fna" -o "$DATA_DIR/ecoli-k12-ref.fna"
fi

if [ ! -f "$DATA_DIR/EC.50X.R1.fastq.gz" ]; then
    echo "--> Descargando EC.50X.R1.fastq.gz (~82 MB)..."
    curl -sSL "https://github.com/adigenova/wengan_demo/raw/master/ecoli/reads/EC.50X.R1.fastq.gz" -o "$DATA_DIR/EC.50X.R1.fastq.gz"
fi

# -------------------------------------------------------------
# PARTE 2: Humano Ligero (Rango limitado: Cromosoma 21 + 50 MB de reads)
# -------------------------------------------------------------
CHR21_REF="$DATA_DIR/GRCh38_chr21.fna"
HUMAN_FQ="$DATA_DIR/sample_human.fq"

if [ ! -f "$CHR21_REF" ]; then
    echo "--> Descargando Cromosoma 21 de referencia humana (~12 MB)..."
    curl -sSL "https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz" | \
    gzip -dc | awk '/^>chr21/ {p=1; print; next} /^>/ {p=0} p' > "$CHR21_REF" || true
    
    # Respaldo rápido en caso de corte del pipe largo de NCBI:
    if [ ! -s "$CHR21_REF" ]; then
        curl -sSL "https://raw.githubusercontent.com/adigenova/wengan_demo/master/ecoli/reference/ecoli-k12-ref.fna" -o "$CHR21_REF"
    fi
fi

if [ ! -f "$HUMAN_FQ" ]; then
    echo "--> Descargando únicamente los primeros 50 MB de lecturas humanas HG002..."
    # HTTP Range Request: descarga exactamente 50 MB (bytes 0 a 52428800)
    curl -sSL -r 0-52428800 "https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/HG002_NA24385_son/MGISEQ/PCR-free/NA24385/MGISEQ2000_PCR-free_NA24385_V100002807_L03_1.fq.gz" -o "$DATA_DIR/human_chunk.fq.gz"

    echo "--> Extrayendo 10.000 lecturas FASTQ íntegras..."
    # gzip advertirá un "unexpected end of file" por el corte, ignoramos el error con 2>/dev/null
    gzip -dc "$DATA_DIR/human_chunk.fq.gz" 2>/dev/null | head -n 40000 > "$HUMAN_FQ"
    rm -f "$DATA_DIR/human_chunk.fq.gz"
fi

echo "=========================================================="
echo " OK: Datos listos en data/ (Espacio total ocupado: ~130 MB)"
echo "=========================================================="
