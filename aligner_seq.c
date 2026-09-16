#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>

#define MAX_LINE_LEN 65536

typedef struct {
    uint32_t count;
    uint64_t position;
} index_cell_t;

typedef struct {
    uint64_t pos;
    int votes;
} candidate_vote_t;

static inline int hash_kmer(const char *s, size_t k, size_t M, size_t *index) {
    if (k == 0 || k > 31 || M == 0) return 0;
    
    uint64_t h = 2166136261ULL;
    for (size_t j = 0; j < k; ++j) {
        uint64_t val;
        switch (s[j]) {
            case 'A': case 'a': val = 0; break;
            case 'C': case 'c': val = 1; break;
            case 'G': case 'g': val = 2; break;
            case 'T': case 't': val = 3; break;
            default: return 0;
        }
        h = (h * 16777619ULL + val) % 4294967296ULL;
    }
    *index = (size_t)(h % M);
    return 1;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <referencia.fna> [k] [L] [M] [c]\n", argv[0]);
        return 1;
    }

    const char *fasta_path = argv[1];
    size_t k = (argc > 2) ? (size_t)atoi(argv[2]) : 15;
    size_t L = (argc > 3) ? (size_t)atoi(argv[3]) : 10;
    size_t M = (argc > 4) ? (size_t)strtoull(argv[4], NULL, 10) : 4641652;
    uint32_t c = (argc > 5) ? (uint32_t)atoi(argv[5]) : 1;

    index_cell_t *table = (index_cell_t *)calloc(M, sizeof(index_cell_t));
    if (!table) return 1;

    FILE *fa = fopen(fasta_path, "r");
    if (!fa) { free(table); return 1; }

    size_t ref_cap = 10485760;
    char *ref_seq = (char *)malloc(ref_cap);
    size_t ref_len = 0;
    char ref_name[256] = "ref";
    char line[MAX_LINE_LEN];

    while (fgets(line, sizeof(line), fa)) {
        if (line[0] == '>') {
            sscanf(line + 1, "%255s", ref_name);
            continue;
        }
        for (char *p = line; *p; ++p) {
            if (isalpha((unsigned char)*p)) {
                if (ref_len + 1 >= ref_cap) {
                    ref_cap *= 2;
                    ref_seq = (char *)realloc(ref_seq, ref_cap);
                }
                ref_seq[ref_len++] = toupper((unsigned char)*p);
            }
        }
    }
    fclose(fa);

    if (ref_len >= k) {
        for (size_t i = 0; i <= ref_len - k; i += L) {
            size_t idx = 0;
            if (hash_kmer(&ref_seq[i], k, M, &idx)) {
                if (table[idx].count == 0) {
                    table[idx].count = 1;
                    table[idx].position = i + 1; // 1-based
                } else {
                    table[idx].count++;
                }
            }
        }
    }
    free(ref_seq);

    /* Metricas experimentales: Factor de ocupacion de la tabla hash */
    size_t occupied_cells = 0;
    for (size_t i = 0; i < M; ++i) {
        if (table[i].count > 0) {
            occupied_cells++;
        }
    }
    double load_factor = (double)occupied_cells / (double)M;
    fprintf(stderr, "[INDEX STATS] Celdas ocupadas: %zu / %zu (Factor de ocupacion: %.4f)\n",
            occupied_cells, M, load_factor);

    printf("read_id\tstatus\treference\tposition\tscore\n");

    char read_id[256];
    char read_seq[MAX_LINE_LEN];
    long line_count = 0;

    while (fgets(line, sizeof(line), stdin)) {
        long mod = line_count % 4;
        if (mod == 0) {
            line[strcspn(line, "\r\n")] = '\0';
            sscanf(line + 1, "%255s", read_id);
        } else if (mod == 1) {
            size_t clean_len = 0;
            for (char *p = line; *p && *p != '\r' && *p != '\n'; ++p) {
                read_seq[clean_len++] = toupper((unsigned char)*p);
            }
            read_seq[clean_len] = '\0';

            candidate_vote_t cand_list[1024];
            int n_cands = 0;

            if (clean_len >= k) {
                for (size_t j = 0; j <= clean_len - k; j += L) {
                    size_t idx = 0;
                    if (hash_kmer(&read_seq[j], k, M, &idx)) {
                        if (table[idx].count > 0 && table[idx].count <= c) {
                            uint64_t p_ref = table[idx].position;
                            size_t p_read = j + 1;

                            if (p_ref >= p_read) {
                                uint64_t p_cand = p_ref - p_read + 1;
                                int found = 0;
                                for (int v = 0; v < n_cands; ++v) {
                                    if (cand_list[v].pos == p_cand) {
                                        cand_list[v].votes++;
                                        found = 1;
                                        break;
                                    }
                                }
                                if (!found && n_cands < 1024) {
                                    cand_list[n_cands].pos = p_cand;
                                    cand_list[n_cands].votes = 1;
                                    n_cands++;
                                }
                            }
                        }
                    }
                }
            }

            int best_score = 0;
            uint64_t best_pos = 0;

            for (int v = 0; v < n_cands; ++v) {
                if (cand_list[v].votes > best_score) {
                    best_score = cand_list[v].votes;
                    best_pos = cand_list[v].pos;
                } else if (cand_list[v].votes == best_score) {
                    if (cand_list[v].pos < best_pos) {
                        best_pos = cand_list[v].pos;
                    }
                }
            }

            if (best_score > 0) {
                printf("%s\thit\t%s\t%lu\t%d\n", read_id, ref_name, (unsigned long)best_pos, best_score);
            } else {
                printf("%s\tno-hit\t*\t0\t0\n", read_id);
            }
        }
        line_count++;
    }

    free(table);
    return 0;
}