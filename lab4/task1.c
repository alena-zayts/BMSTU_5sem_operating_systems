#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

#define RET_OK 0
#define RET_ERR_FORK 1

#define FORK_OK 0
#define FORK_ERR -1

#define INTERVAL 1

int main()
{
	pid_t childpid1, childpid2;
	if ((childpid1 = fork()) == FORK_ERR)
	{
		perror("Can't fork first child process.\n");
		return RET_ERR_FORK;
	}
	else if (childpid1 == FORK_OK)
	{
		printf("First child process: pid = %d, ppid = %d, pgrp = %d\n", 
				getpid(), getppid(), getpgrp());
				
		sleep(INTERVAL);
		printf("First child process (has become an orphan): pid = %d, ppid = %d, pgrp = %d\n", 
					getpid(), getppid(), getpgrp());
		
		printf("First child process is dead now\n");
		
		exit(RET_OK);
	}


	if ((childpid2 = fork()) == FORK_ERR)
	{
		perror("Can't fork second child process.\n");
		return RET_ERR_FORK;
	}
	else if (childpid2 == FORK_OK)
	{
		printf("Second child process: pid = %d, ppid = %d, pgrp = %d\n", 
					getpid(), getppid(), getpgrp());
					
		sleep(INTERVAL);
		printf("Second child process (has become an orphan): pid = %d, ppid = %d, pgrp = %d\n", 
					getpid(), getppid(), getpgrp());

		printf("Second child process is dead now\n");
		exit(RET_OK);
	}

	printf("Parent process: pid = %d, pgrp = %d, childpid1 = %d, childpid2 = %d\n", 
				getpid(), getpgrp(), childpid1, childpid2);
	printf("Parent process is dead now\n");
	return RET_OK;

}
