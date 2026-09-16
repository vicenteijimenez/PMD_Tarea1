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

´´´text
.
├── Makefile                # Automatización de compilación, ejecución, reporte y descarga
├── README.md               # Documentación general y guía de uso
├── .gitignore              # Exclusión de binarios, salidas temporales y datos biológicos
├── run_problema_1.sh       # Script con las soluciones a la Parte 1 (incisos a-j)
├── aligner.awk             # Parte 2: Implementación secuencial en AWK (FNV-1a 53-bit)
├── aligner_seq.c           # Parte 2: Implementación secuencial optimizada en C (-O3)
├── aligner_pthreads.c      # Parte 2: Implementación multihilo en C (Pthreads + Buffer de Reorden)
├── informe.tex             # Código fuente en LaTeX del informe formal
├── informe.pdf             # Informe técnico final compilado en PDF
├── scripts/
│   └── download_data.sh    # Descarga automatizada y preparación ligera de datasets
├── tests/
│   ├── test_ecoli.sh       # Suite automatizada de pruebas para E. coli (AWK vs C vs Pthreads)
│   ├── test_human.sh       # Suite automatizada de pruebas para Homo sapiens (GRCh38)
│   └── stats.awk           # Analizador de distribución de aciertos (hits) y puntajes
└── data/                   # Directorio de insumos (ignorado por Git, generado con make data)
    ├── worldcitiespop.csv.gz
    ├── matrix.txt
    ├── ecoli-k12-ref.fna
    ├── EC.50X.R1.fastq.gz
    ├── GRCh38_chr21.fna
    └── sample_human.fq
´´´
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

### Obtención y Carga de Datos

Los archivos biológicos y datasets masivos superan el límite de tamaño de GitHub y están excluidos en `.gitignore`. Para inicializar el directorio `data/` con todos los insumos necesarios (Para el genoma humano solo se descargara el genoma 21, esto debido a que GRCh38 full es muy pesado (>50 GB + ref)):

```bash
make data

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

* Validación en E. coli (AWK vs C secuencial vs C pthreads):

```bash
make test-ecoli

```


* Validación en Homo sapiens (C secuencial vs C pthreads sobre chr21):

```bash
make test-human

```

* Suite completa de pruebas (Parte 1 + E. coli + Humano):
```bash
make test

```

### Limpieza de Archivos Temporales

```bash
make clean

```

---