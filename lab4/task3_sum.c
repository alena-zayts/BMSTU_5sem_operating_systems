#include <stdio.h>
#include <stdlib.h>

#define RET_OK 0
#define RET_ERR_PARAM -1

int main(int argc, char **argv)
{
	int a, b;
	
	printf("This is program called from first child\n");
	
	if ((argc != 3) || 
		((a = atoi(argv[1])) <= 0) || 
		((b = atoi(argv[2])) <= 0))
	{
		printf("Error: got wrong arguments\n");
        return RET_ERR_PARAM;
	}

	printf("I can count sum: %d + %d = %d\n", a, b, (a + b));
	return RET_OK;
}