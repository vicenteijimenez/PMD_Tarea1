#!/usr/bin/env awk -f

BEGIN {
    if (!k) k = 15;
    if (!L) L = 10;
    if (!M) M = 4641652;
    if (!c) c = 1;

    total_reads = 0;
    hit_reads = 0;
    nohit_reads = 0;
    stats_printed = 0;
}

# -------------------------------------------------------------
# FASE 1: FASTA (ARGIND == 1)
# -------------------------------------------------------------
ARGIND == 1 {
    gsub(/[\r\n]/, "", $0);
    if ($0 ~ /^>/) {
        if (ref_seq != "") {
            index_reference(current_ref, ref_seq);
            ref_seq = "";
        }
        sub(/^>/, "", $0);
        split($0, arr, /[ \t]/);
        current_ref = arr[1];
        next;
    }
    gsub(/[ \t]/, "", $0);
    ref_seq = ref_seq toupper($0);
    next;
}

# -------------------------------------------------------------
# Transición FASTA -> FASTQ
# -------------------------------------------------------------
ARGIND == 2 && FNR == 1 {
    if (ref_seq != "") {
        index_reference(current_ref, ref_seq);
        ref_seq = "";
    }
}

# -------------------------------------------------------------
# FASE 2: FASTQ (ARGIND == 2)
# -------------------------------------------------------------
ARGIND == 2 {
    if (!stats_printed) {
        occupied = 0;
        for (idx in table_count) {
            if (table_count[idx] > 0) occupied++;
        }
        printf("[INDEX STATS] Celdas ocupadas: %d / %d (Factor de ocupacion: %.4f)\n", 
               occupied, M, occupied / M) > "/dev/stderr";

        printf "read_id\tstatus\treference\tposition\tscore\n";
        stats_printed = 1;
    }

    gsub(/[\r\n]/, "", $0);
    line_mod = (FNR - 1) % 4;

    if (line_mod == 0) {
        sub(/^@/, "", $0);
        split($0, arr, /[ \t]/);
        current_read_id = arr[1];
    } else if (line_mod == 1) {
        total_reads++;
        gsub(/[ \t]/, "", $0);
        process_read(current_read_id, toupper($0));
    }
    next;
}

# -------------------------------------------------------------
# Funciones
# -------------------------------------------------------------
function hash_kmer(str, mod_val,    len, h, i, ch, val) {
    len = length(str);
    h = 2166136261;
    for (i = 1; i <= len; i++) {
        ch = substr(str, i, 1);
        if (ch == "A") val = 0;
        else if (ch == "C") val = 1;
        else if (ch == "G") val = 2;
        else if (ch == "T") val = 3;
        else return -1;

        h = (h * 16777619 + val) % 4294967296;
    }
    return h % mod_val;
}

function index_reference(ref_name, seq,    seq_len, i, kmer, idx) {
    seq_len = length(seq);
    for (i = 1; i <= seq_len - k + 1; i += L) {
        kmer = substr(seq, i, k);
        idx = hash_kmer(kmer, M);
        if (idx != -1) {
            if (!(idx in table_count)) {
                table_count[idx] = 1;
                table_pos[idx] = i;
                table_ref[idx] = ref_name;
            } else {
                table_count[idx]++;
            }
        }
    }
}

function process_read(read_id, seq,    read_len, i, kmer, idx, p_ref, p_cand, votes, cand_ref, best_cand, best_score, best_ref, cand, score, cand_num) {
    read_len = length(seq);
    delete votes;
    delete cand_ref;

    for (i = 1; i <= read_len - k + 1; i += L) {
        kmer = substr(seq, i, k);
        idx = hash_kmer(kmer, M);

        if (idx != -1 && (idx in table_count)) {
            if (table_count[idx] <= c) {
                p_ref = table_pos[idx];
                if (p_ref >= i) {
                    p_cand = p_ref - i + 1;
                    votes[p_cand]++;
                    cand_ref[p_cand] = table_ref[idx];
                }
            }
        }
    }

    best_score = 0;
    best_cand = 0;
    best_ref = "*";

    for (cand in votes) {
        score = votes[cand];
        cand_num = cand + 0;
        if (score > best_score) {
            best_score = score;
            best_cand = cand_num;
            best_ref = cand_ref[cand];
        } else if (score == best_score) {
            if (cand_num < best_cand) {
                best_cand = cand_num;
                best_ref = cand_ref[cand];
            }
        }
    }

    if (best_score > 0) {
        hit_reads++;
        printf "%s\thit\t%s\t%d\t%d\n", read_id, best_ref, best_cand, best_score;
    } else {
        nohit_reads++;
        printf "%s\tno-hit\t*\t0\t0\n", read_id;
    }
}