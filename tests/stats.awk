BEGIN { FS="\t" }
NR > 1 {
    total++;
    status = $2;
    score = $5;
    if (status == "hit") {
        hits++;
    } else {
        nohits++;
    }
    scores[score]++;
}
END {
    printf "  - Total lecturas: %d\n", total;
    if (total > 0) {
        printf "  - Hits (aciertos): %d (%.2f%%)\n", hits, (hits/total)*100;
        printf "  - No-hits: %d (%.2f%%)\n", nohits, (nohits/total)*100;
        printf "  - Desglose de puntajes:\n";
        for (s in scores) {
            printf "      Score %2s: %d lecturas (%.2f%%)\n", s, scores[s], (scores[s]/total)*100;
        }
    }
}
