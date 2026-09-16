# Tarea 1: Procesamiento de Texto con AWK y Alineamiento Probabilístico de k-meros

**Autores:** Vicente Jiménez y Marco Pérez

**Entorno de desarrollo:** WSL2 (Ubuntu 24.04 LTS), Intel Core i5-10300H CPU @ 2.50GHz (8 vCPUs), 8GB RAM

**Asignatura:** Programación Masivo de Datos

---

## Descripción del Proyecto

Este proyecto aborda la resolución de problemas de procesamiento masivo de datos divididos en dos áreas principales:

1. **Parte 1 (Procesamiento de Archivos Tabulares con AWK):** Procesamiento de flujos de texto en streaming sobre datos demográficos globales (`worldcitiespop.csv.gz`) y análisis matricial bidimensional (`matrix.txt`).
2. **Parte 2 (Alineamiento Probabilístico de k-meros):** Algoritmo probabilístico de posicionamiento de lecturas FASTQ sobre genomas de referencia mediante una tabla hash de acceso directo sin resolución de colisiones, evaluado en AWK, C secuencial y C con POSIX Threads.

---

## Estructura del Repositorio

* **`Makefile`**: Automatización del ciclo de compilación, ejecución de tests.
* **`README.md`**: Documentación técnica y guía de reproducción.
* **`.gitignore`**: Exclusión de archivos binarios, salidas temporales y carpetas de datos genómicos.
* **`run_problema1.sh`**: Script interactivo con las soluciones a los incisos 1.a al 1.j.
* **`aligner.awk`**: Alineador secuencial implementado en GNU Awk (con aritmética FNV-1a compatible con mantisa de 53 bits).
* **`aligner_seq.c`**: Alineador secuencial de alto rendimiento escrito en C (`-O3`).


* **`aligner_pthreads.c`**: Alineador concurrente con arquitectura Productor-Consumidor y buffer de reordenamiento monotónico para asegurar salidas idénticas en orden FIFO.
* **`tests/run_tests.sh`**: Suite de validación automatizada mediante comparaciones binarias (`cmp`).
* **`tests/stats.awk`**: Script auxiliar para el desglose de tasas de hits y distribución de frecuencias de puntajes.
* **`data/`**: Carpeta local para los datasets de referencia y lecturas (no incluida en el control de versiones).

---

## Parte 1: Procesamiento de Archivos Tabulares

El script `run_problema1.sh` resuelve las consultas requeridas:

* **1.a:** Promedio de habitantes por ciudad agrupado por país (omitiendo registros sin población).
* **1.b:** Las 10 ciudades con mayor población en orden descendente.
* **1.c:** Porcentaje y razón de ciudades sin registro poblacional por país.
* **1.d:** Población continental total de Sudamérica y la ciudad más habitada junto a su país.
* **1.e:** Valores mínimos y máximos por columna en `matrix.txt`.
* **1.f:** Inversión de columnas registro por registro.
* **1.g:** Filtrado en dos pasadas (`NR == FNR`) de filas cuyo promedio supera el promedio total de la matriz.
* **1.h:** Conteo global de números impares.
* **1.i:** Conteo de números divisibles por 4, por 9 y por ambos simultáneamente.
* **1.j:** Identificación y despliegue de la fila con mayor suma acumulada.

---

## Parte 2: Alineamiento Probabilístico de k-meros

### Parámetros de Configuración

* **`k`**: Tamaño de la semilla ($k$-mero). Por defecto: `15`.


* **`L`**: Salto o paso de muestreo (*stride*). Por defecto: `10`.


* **`M`**: Cantidad de ranuras de la tabla hash. Por defecto: `4641652`.


* **`c`**: Umbral de visitas máximas permitidas para considerar una celda válida. Por defecto: `1`.


* **`hilos`**: Subprocesos trabajadores activos en Pthreads. Por defecto: `4`.
* **`X`**: Número de registros FASTQ agrupados por bloque. Por defecto: `1000`.
* **`Y`**: Capacidad máxima de la cola bloqueante de tareas. Por defecto: `64`.

---

## Compilación y Ejecución

### Compilación de Binarios

```bash
make

```

### Ejecución de la Parte 1

* Todos los ejercicios:
```bash
make test-p1

```


* Un ejercicio individual (ejemplo: 1.d):
```bash
./run_problema1.sh d

```



### Ejecución de la Parte 2

* Suite de pruebas y validación comparativa (AWK vs C Secuencial vs Pthreads):
```bash
make test-p2

```


* Batería completa de pruebas (Parte 1 y Parte 2):
```bash
make test

```



### Limpieza de Archivos Temporales

```bash
make clean

```

---

## Reproducibilidad de Muestras (Genoma Humano)

Para la evaluación sobre *Homo sapiens*, se extrae una muestra de control de 1.000 lecturas desde el archivo original utilizando Python:

```bash
python3 -c '
import gzip
with gzip.open("data/HG002-MGISEQ-L03-1.fq.gz", "rt") as fin, open("data/sample_1000.fq", "w") as fout:
    for i in range(4000):
        line = fin.readline()
        if not line: break
        fout.write(line)
'

```

La referencia reducida de prueba se genera con:

```bash
head -n 500000 data/GRCh38_ref.fna > data/GRCh38_test_small.fna

```