CC = gcc
CFLAGS = -O3 -Wall -Wextra
PTHREAD_FLAGS = -pthread
LATEX = pdflatex

TARGETS = aligner_seq aligner_pthreads
REPORT = informe.pdf

.PHONY: all clean test test-p1 test-ecoli test-human report data setup help

all: $(TARGETS)

aligner_seq: aligner_seq.c
	$(CC) $(CFLAGS) $< -o $@

aligner_pthreads: aligner_pthreads.c
	$(CC) $(CFLAGS) $(PTHREAD_FLAGS) $< -o $@

report: $(REPORT)

$(REPORT): informe.tex
	$(LATEX) informe.tex
	$(LATEX) informe.tex

data:
	@chmod +x scripts/download_data.sh
	./scripts/download_data.sh

setup: data all

test-p1:
	@chmod +x run_problema1.sh
	./run_problema1.sh all

test-ecoli: all
	@chmod +x tests/test_ecoli.sh
	./tests/test_ecoli.sh

test-human: all
	@chmod +x tests/test_human.sh
	./tests/test_human.sh

# Ejecuta todas las pruebas en secuencia
test: test-p1 test-ecoli test-human

clean:
	rm -f $(TARGETS)
	rm -f *.aux *.log *.out *.toc *.synctex.gz
	rm -rf resultados/
	@echo "Limpieza completada."