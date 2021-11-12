#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define RET_OK 0
#define RET_ERR_PARAM -1
#define RET_ERR_FILE -2

int main(int argc, char **argv)
{
	printf("This is program called from second child\n");
	
	if (argc != 3)
	{
		printf("Error: got wrong arguments\n");
        return RET_ERR_PARAM;
	}
	
	FILE *f = fopen(argv[1], "w");
	if (!f)
	{
		printf("Error: cant open file\n");
        return RET_ERR_FILE;
	}

	printf("I can write given info and info about myself here and to given file %s\n", argv[1]);
	
	fprintf(f, "Given info: %s\n", argv[2]);
	fprintf(stdout, "Given info: %s\n", argv[2]);
	
	fprintf(f, "Info about myself: pid = %d, ppid = %d, pgrp = %d\n", 
					getpid(), getppid(), getpgrp());
	fprintf(stdout, "Info about myself: pid = %d, ppid = %d, pgrp = %d\n", 
					getpid(), getppid(), getpgrp());
	
	fclose(f);
	
	return RET_OK;
}