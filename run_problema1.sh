#!/bin/bash
# run_problema  1.sh

# gzip -dc data/worldcitiespop.csv.gz | awk -F',' '...'
# Primero se descomprime con 'gzip -dc' para enviar el texto directamente a la salida estándar sin extraer archivos en disco.
# Se usa la pipeline '|' para pasar ese flujo de texto directamente a awk sin guardar nada intermedio.
# - Usamos la flag -F ',' para indicar que el separador de columnas del CSV es la coma.

a() {
    echo "1.a: Promedio de habitantes por ciudad y país"
    gzip -dc data/worldcitiespop.csv.gz | awk -F',' 'NR > 1 && $5 != "" && $5 > 0 {
        sum[$1] += $5; count[$1]++
    } END {
        for (c in sum) printf "%s\t%.2f\n", c, sum[c] / count[c]
    }' | sort -k1,1 | head -n 20
}

b() {
    echo "1.b: 10 ciudades con mayor población"
    gzip -dc data/worldcitiespop.csv.gz | awk -F',' 'NR > 1 && $5 ~ /^[0-9]+$/ {
        print $5, $3, $1
    }' | sort -k1,1nr | head -n 10
}

c() {
    echo "1.c: Porcentaje de ciudades sin población por país"
    gzip -dc data/worldcitiespop.csv.gz | awk -F',' 'NR > 1 {
        total[$1]++
        if ($5 == "" || $5 == 0) no_pop[$1]++
    } END {
        for (c in total) {
            pct = (no_pop[c] / total[c]) * 100
            printf "%s\t%.2f%%\t(%d/%d)\n", c, pct, no_pop[c], total[c]
        }
    }' | sort -k1,1 | head -n 20
}

d() {
    echo "1.d: Habitantes y ciudad más poblada de Sudamérica"
    gzip -dc data/worldcitiespop.csv.gz | awk -F',' '
    BEGIN {
        split("ar bo br cl co ec fk gf gy pe py sr uy ve", sa, " ")
        for (i in sa) is_sa[sa[i]] = 1
        max_pop = -1
    }
    NR > 1 && ($1 in is_sa) && $5 ~ /^[0-9]+$/ {
        total_pop += $5
        if ($5 > max_pop) {
            max_pop = $5; top_city = $3; top_country = $1
        }
    } END {
        printf "Población total América del Sur: %d\n", total_pop
        printf "Ciudad más poblada: %s (%s) con %d habitantes\n", top_city, top_country, max_pop
    }'
}

e() {
    echo "1.e: Mínimo y máximo por columna (matrix.txt)"
    awk '{
        for (i = 1; i <= NF; i++) {
            if (NR == 1 || $i > max[i]) max[i] = $i
            if (NR == 1 || $i < min[i]) min[i] = $i
        }
    } END {
        for (i = 1; i <= length(max); i++) printf "Col %d: Min = %d, Max = %d\n", i, min[i], max[i]
    }' data/matrix.txt
}

f() {
    echo "1.f: Invertir columnas (matrix.txt) [Primeras 3 filas de muestra]"
    awk '{
        for (i = NF; i >= 1; i--) printf "%s%s", $i, (i == 1 ? RS : FS)
    }' data/matrix.txt | head -n 3
}

g() {
    echo "1.g: Filas con promedio mayor al promedio global (matrix.txt)"
    awk 'NR == FNR {
        for (i = 1; i <= NF; i++) { total_sum += $i; total_cnt++ }
        next
    }
    FNR == 1 { global_avg = total_sum / total_cnt }
    {
        row_sum = 0
        for (i = 1; i <= NF; i++) row_sum += $i
        if ((row_sum / NF) > global_avg) print "Fila " FNR " (Prom: " row_sum/NF " > Global: " global_avg ")"
    }' data/matrix.txt data/matrix.txt
}

h() {
    echo "1.h: Cantidad de impares (matrix.txt)"
    awk '{
        for (i = 1; i <= NF; i++) if ($i % 2 != 0) odds++
    } END { print "Total impares:", odds }' data/matrix.txt
}

i() {
    echo "1.i: Divisibles por 4, por 9 y simultáneos (matrix.txt)"
    awk '{
        for (i = 1; i <= NF; i++) {
            d4 = ($i % 4 == 0); d9 = ($i % 9 == 0)
            if (d4) c4++; if (d9) c9++
            if (d4 && d9) c_both++
        }
    } END {
        printf "Divisibles por 4: %d\n", c4
        printf "Divisibles por 9: %d\n", c9
        printf "Divisibles por ambos: %d\n", c_both
    }' data/matrix.txt
}

j() {
    echo "1.j: Fila con mayor suma acumulada (matrix.txt)"
    awk '{
        sum = 0
        for (i = 1; i <= NF; i++) sum += $i
        if (NR == 1 || sum > max_sum) {
            max_sum = sum; best_row = $0; best_idx = NR
        }
    } END {
        print "Fila:", best_idx, "(Suma =", max_sum ")"
        print best_row
    }' data/matrix.txt
}

all() {
    a; echo ""
    b; echo ""
    c; echo ""
    d; echo ""
    e; echo ""
    f; echo ""
    g; echo ""
    h; echo ""
    i; echo ""
    j
}

OPCION=${1:-all}

case $OPCION in
    a|A) a ;;
    b|B) b ;;
    c|C) c ;;
    d|D) d ;;
    e|E) e ;;
    f|F) f ;;
    g|G) g ;;
    h|H) h ;;
    i|I) i ;;
    j|J) j ;;
    all|ALL) all ;;
    *)
        echo "Uso: $0 [a|b|c|d|e|f|g|h|i|j|all]"
        exit 1
        ;;
esac