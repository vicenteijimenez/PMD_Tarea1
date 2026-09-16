CC = gcc
CFLAGS = -O3 -Wall -Wextra
PTHREAD_FLAGS = -pthread
LATEX = pdflatex

TARGETS = aligner_seq aligner_pthreads
REPORT = informe.pdf

.PHONY: all clean test test-p1 test-p2 report help

all: $(TARGETS)

aligner_seq: aligner_seq.c
	$(CC) $(CFLAGS) $< -o $@

aligner_pthreads: aligner_pthreads.c
	$(CC) $(CFLAGS) $(PTHREAD_FLAGS) $< -o $@

report: $(REPORT)

$(REPORT): informe.tex
	$(LATEX) informe.tex
	$(LATEX) informe.tex

test-p1:
	@chmod +x run_problema1.sh
	./run_problema1.sh all

test-p2: all
	@chmod +x tests/run_tests.sh
	./tests/run_tests.sh

test: test-p1 test-p2

clean:
	rm -f $(TARGETS)
	rm -f *.aux *.log *.out *.toc *.synctex.gz
	rm -rf resultados/
	@echo "Limpieza completada."

help:
	@echo "Opciones disponibles:"
	@echo "  make         Compila los ejecutables en C de la Parte 2"
	@echo "  make test    Ejecuta las pruebas completas (Parte 1 y Parte 2)"
	@echo "  make test-p1 Ejecuta los ejercicios de AWK (Parte 1)"
	@echo "  make test-p2 Compila y ejecuta las pruebas de alineamiento (Parte 2)"
	@echo "  make report  Genera informe.pdf con pdflatex"
	@echo "  make clean   Elimina ejecutables y temporales"