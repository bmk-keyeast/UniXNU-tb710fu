// Host harness: writes zone images with the kernel writer for verify_ramoops.py.
#define TB710FU_RAMOOPS_HOSTTEST 1
#include "tb710fu_ramoops.c"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void dump(const char *path, uint8_t *z, size_t n) { FILE *f = fopen(path, "wb"); fwrite(z, 1, n, f); fclose(f); }
static void puts_zone(const char *s) { while (*s) ramoops_zone_putc(*s++); }

int main(int argc, char **argv)
{
	const char *dir = argv[1];
	char path[512];
	srand(1);

	/* 1: the stock console zone (0x40000, ecc 16), random RAM, two boots appended */
	size_t n = 0x40000;
	uint8_t *z = malloc(n);
	for (size_t i = 0; i < n; i++) z[i] = rand();
	if (ramoops_zone_open(z, n, 16)) return 1;
	puts_zone("boot one\nline two\n");
	puts_zone("no newline at the end");
	ramoops_zone_flush();
	if (ramoops_zone_open(z, n, 16)) return 1;   /* next boot: append */
	puts_zone("\nboot two\n");
	snprintf(path, sizeof path, "%s/append.bin", dir); dump(path, z, n);

	/* 2: a small zone that wraps several times */
	n = 4096;
	z = malloc(n);
	memset(z, 0, n);
	if (ramoops_zone_open(z, n, 16)) return 1;
	for (int i = 0; i < 1000; i++) { char l[32]; snprintf(l, sizeof l, "line %04d\n", i); puts_zone(l); }
	snprintf(path, sizeof path, "%s/wrap.bin", dir); dump(path, z, n);

	/* 3: ecc disabled */
	n = 8192;
	z = calloc(1, n);
	if (ramoops_zone_open(z, n, 0)) return 1;
	puts_zone("plain\n");
	snprintf(path, sizeof path, "%s/noecc.bin", dir); dump(path, z, n);
	return 0;
}
