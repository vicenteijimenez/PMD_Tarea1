#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>
#include <pthread.h>

#define MAX_LINE_LEN 65536
#define MAX_ID_LEN 128
#define MAX_SEQ_LEN 1024

typedef struct {
    uint32_t count;
    uint64_t position;
} index_cell_t;

typedef struct {
    uint64_t pos;
    int votes;
} candidate_vote_t;

typedef struct {
    char id[MAX_ID_LEN];
    char seq[MAX_SEQ_LEN];
    uint64_t best_pos;
    int best_score;
} read_record_t;

typedef struct {
    uint64_t block_id;
    int num_reads;
    read_record_t *reads;
} read_block_t;

typedef struct {
    read_block_t **buffer;
    int capacity;
    int count;
    int head;
    int tail;
    int finished;
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
    pthread_cond_t not_full;
} bounded_queue_t;

static index_cell_t *g_table = NULL;
static size_t g_k = 15;
static size_t g_L = 10;
static size_t g_M = 4641652;
static uint32_t g_c = 1;
static char g_ref_name[256] = "ref";

static bounded_queue_t g_work_queue;

/* Buffer de bloques completados */
static read_block_t **g_completed_blocks = NULL;
static pthread_mutex_t g_completed_lock;
static pthread_cond_t g_completed_cond;
static uint64_t g_next_to_print = 0;

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

static void process_single_read(read_record_t *r) {
    size_t rlen = strlen(r->seq);
    candidate_vote_t cand_list[1024];
    int n_cands = 0;

    if (rlen >= g_k) {
        for (size_t j = 0; j <= rlen - g_k; j += g_L) {
            size_t idx = 0;
            if (hash_kmer(&r->seq[j], g_k, g_M, &idx)) {
                if (g_table[idx].count > 0 && g_table[idx].count <= g_c) {
                    uint64_t p_ref = g_table[idx].position;
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

    r->best_score = best_score;
    r->best_pos = best_pos;
}

void *worker_thread_func(void *arg) {
    (void)arg;
    while (1) {
        read_block_t *block = NULL;

        pthread_mutex_lock(&g_work_queue.lock);
        while (g_work_queue.count == 0 && !g_work_queue.finished) {
            pthread_cond_wait(&g_work_queue.not_empty, &g_work_queue.lock);
        }
        if (g_work_queue.count == 0 && g_work_queue.finished) {
            pthread_mutex_unlock(&g_work_queue.lock);
            break;
        }

        block = g_work_queue.buffer[g_work_queue.head];
        g_work_queue.head = (g_work_queue.head + 1) % g_work_queue.capacity;
        g_work_queue.count--;
        pthread_cond_signal(&g_work_queue.not_full);
        pthread_mutex_unlock(&g_work_queue.lock);

        for (int i = 0; i < block->num_reads; ++i) {
            process_single_read(&block->reads[i]);
        }

        pthread_mutex_lock(&g_completed_lock);
        g_completed_blocks[block->block_id] = block;
        pthread_cond_signal(&g_completed_cond);
        pthread_mutex_unlock(&g_completed_lock);
    }
    return NULL;
}

void *printer_thread_func(void *arg) {
    uint64_t total_blocks = *(uint64_t *)arg;

    printf("read_id\tstatus\treference\tposition\tscore\n");

    while (g_next_to_print < total_blocks) {
        pthread_mutex_lock(&g_completed_lock);
        while (g_completed_blocks[g_next_to_print] == NULL) {
            pthread_cond_wait(&g_completed_cond, &g_completed_lock);
        }
        read_block_t *block = g_completed_blocks[g_next_to_print];
        g_completed_blocks[g_next_to_print] = NULL;
        g_next_to_print++;
        pthread_mutex_unlock(&g_completed_lock);

        for (int i = 0; i < block->num_reads; ++i) {
            read_record_t *r = &block->reads[i];
            if (r->best_score > 0) {
                printf("%s\thit\t%s\t%lu\t%d\n", r->id, g_ref_name, (unsigned long)r->best_pos, r->best_score);
            } else {
                printf("%s\tno-hit\t*\t0\t0\n", r->id);
            }
        }

        free(block->reads);
        free(block);
    }
    return NULL;
}

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;

    const char *fasta_path = argv[1];
    g_k = (argc > 2) ? (size_t)atoi(argv[2]) : 15;
    g_L = (argc > 3) ? (size_t)atoi(argv[3]) : 10;
    g_M = (argc > 4) ? (size_t)strtoull(argv[4], NULL, 10) : 4641652;
    g_c = (argc > 5) ? (uint32_t)atoi(argv[5]) : 1;
    int num_threads = (argc > 6) ? atoi(argv[6]) : 4;
    int block_size_X = (argc > 7) ? atoi(argv[7]) : 1000;
    int queue_cap_Y = (argc > 8) ? atoi(argv[8]) : 64;

    g_table = (index_cell_t *)calloc(g_M, sizeof(index_cell_t));
    if (!g_table) return 1;

    FILE *fa = fopen(fasta_path, "r");
    if (!fa) { free(g_table); return 1; }

    size_t ref_cap = 10485760;
    char *ref_seq = (char *)malloc(ref_cap);
    size_t ref_len = 0;
    char line[MAX_LINE_LEN];

    while (fgets(line, sizeof(line), fa)) {
        if (line[0] == '>') {
            sscanf(line + 1, "%255s", g_ref_name);
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

    if (ref_len >= g_k) {
        for (size_t i = 0; i <= ref_len - g_k; i += g_L) {
            size_t idx = 0;
            if (hash_kmer(&ref_seq[i], g_k, g_M, &idx)) {
                if (g_table[idx].count == 0) {
                    g_table[idx].count = 1;
                    g_table[idx].position = i + 1;
                } else {
                    g_table[idx].count++;
                }
            }
        }
    }
    free(ref_seq);

    size_t occupied_cells = 0;
    for (size_t i = 0; i < g_M; ++i) {
        if (g_table[i].count > 0) occupied_cells++;
    }
    double load_factor = (double)occupied_cells / (double)g_M;
    fprintf(stderr, "[INDEX STATS] Celdas ocupadas: %zu / %zu (Factor de ocupacion: %.4f)\n",
            occupied_cells, g_M, load_factor);

    // Cola de trabajo
    g_work_queue.capacity = queue_cap_Y;
    g_work_queue.buffer = (read_block_t **)malloc(sizeof(read_block_t *) * queue_cap_Y);
    g_work_queue.count = 0;
    g_work_queue.head = 0;
    g_work_queue.tail = 0;
    g_work_queue.finished = 0;
    pthread_mutex_init(&g_work_queue.lock, NULL);
    pthread_cond_init(&g_work_queue.not_empty, NULL);
    pthread_cond_init(&g_work_queue.not_full, NULL);

    // Buffer global de bloques indexado por ID (hasta 1 millón de bloques)
    size_t max_total_blocks = 1000000;
    g_completed_blocks = (read_block_t **)calloc(max_total_blocks, sizeof(read_block_t *));
    pthread_mutex_init(&g_completed_lock, NULL);
    pthread_cond_init(&g_completed_cond, NULL);

    pthread_t *workers = (pthread_t *)malloc(sizeof(pthread_t) * num_threads);
    for (int t = 0; t < num_threads; ++t) {
        pthread_create(&workers[t], NULL, worker_thread_func, NULL);
    }

    uint64_t current_block_id = 0;
    read_block_t *curr_block = (read_block_t *)malloc(sizeof(read_block_t));
    curr_block->block_id = current_block_id;
    curr_block->num_reads = 0;
    curr_block->reads = (read_record_t *)malloc(sizeof(read_record_t) * block_size_X);

    char read_id[MAX_ID_LEN];
    long line_count = 0;

    while (fgets(line, sizeof(line), stdin)) {
        long mod = line_count % 4;
        if (mod == 0) {
            line[strcspn(line, "\r\n")] = '\0';
            sscanf(line + 1, "%127s", read_id);
        } else if (mod == 1) {
            read_record_t *r = &curr_block->reads[curr_block->num_reads];
            strncpy(r->id, read_id, sizeof(r->id) - 1);
            r->id[sizeof(r->id) - 1] = '\0';

            size_t clean_len = 0;
            for (char *p = line; *p && *p != '\r' && *p != '\n'; ++p) {
                r->seq[clean_len++] = toupper((unsigned char)*p);
            }
            r->seq[clean_len] = '\0';
            curr_block->num_reads++;

            if (curr_block->num_reads == block_size_X) {
                pthread_mutex_lock(&g_work_queue.lock);
                while (g_work_queue.count == g_work_queue.capacity) {
                    pthread_cond_wait(&g_work_queue.not_full, &g_work_queue.lock);
                }
                g_work_queue.buffer[g_work_queue.tail] = curr_block;
                g_work_queue.tail = (g_work_queue.tail + 1) % g_work_queue.capacity;
                g_work_queue.count++;
                pthread_cond_signal(&g_work_queue.not_empty);
                pthread_mutex_unlock(&g_work_queue.lock);

                current_block_id++;
                curr_block = (read_block_t *)malloc(sizeof(read_block_t));
                curr_block->block_id = current_block_id;
                curr_block->num_reads = 0;
                curr_block->reads = (read_record_t *)malloc(sizeof(read_record_t) * block_size_X);
            }
        }
        line_count++;
    }

    if (curr_block->num_reads > 0) {
        pthread_mutex_lock(&g_work_queue.lock);
        while (g_work_queue.count == g_work_queue.capacity) {
            pthread_cond_wait(&g_work_queue.not_full, &g_work_queue.lock);
        }
        g_work_queue.buffer[g_work_queue.tail] = curr_block;
        g_work_queue.tail = (g_work_queue.tail + 1) % g_work_queue.capacity;
        g_work_queue.count++;
        pthread_cond_signal(&g_work_queue.not_empty);
        pthread_mutex_unlock(&g_work_queue.lock);
        current_block_id++;
    } else {
        free(curr_block->reads);
        free(curr_block);
    }

    uint64_t total_blocks_produced = current_block_id;
    pthread_t printer_th;
    pthread_create(&printer_th, NULL, printer_thread_func, &total_blocks_produced);

    pthread_mutex_lock(&g_work_queue.lock);
    g_work_queue.finished = 1;
    pthread_cond_broadcast(&g_work_queue.not_empty);
    pthread_mutex_unlock(&g_work_queue.lock);

    for (int t = 0; t < num_threads; ++t) {
        pthread_join(workers[t], NULL);
    }
    pthread_join(printer_th, NULL);

    pthread_mutex_destroy(&g_work_queue.lock);
    pthread_cond_destroy(&g_work_queue.not_empty);
    pthread_cond_destroy(&g_work_queue.not_full);
    pthread_mutex_destroy(&g_completed_lock);
    pthread_cond_destroy(&g_completed_cond);
    free(g_work_queue.buffer);
    free(g_completed_blocks);
    free(workers);
    free(g_table);

    return 0;
}