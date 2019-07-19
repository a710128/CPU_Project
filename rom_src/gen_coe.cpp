#include <cstdio>
int main() {
	unsigned char a1, a2, a3, a4;
	FILE *fp = fopen("rom.bin", "rb");
	FILE *fout = fopen("rom.coe", "w");
	
	fprintf(fout, "memory_initialization_radix=16;\n");
	fprintf(fout, "memory_initialization_vector=");
	bool first = true;
	
	while ( fscanf(fp, "%c%c%c%c", &a1, &a2, &a3, &a4) == 4 ) {
		unsigned int b1 = a1;
		unsigned int b2 = a2;
		unsigned int b3 = a3;
		unsigned int b4 = a4;
		unsigned int out = b1 | (b2 << 8) | (b3 << 16) | (b4 << 24);
		if (first) {
			first = false;
		}
		else {
			fprintf(fout, " ");
		}
		fprintf(fout, "%08x", out);
	}
	fprintf(fout, ";\n");
	fclose(fp);
	fclose(fout);
	return 0;
}