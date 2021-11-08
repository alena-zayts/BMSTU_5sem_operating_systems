#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>

#define RET_OK 0
#define RET_ERR_FORK 1
#define RET_CANT_EXECLP 2

#define FORK_OK 0
#define FORK_ERR -1

#define INTERVAL 1

int main()
{
	pid_t childpid1, childpid2, childpid;
	if ((childpid1 = fork()) == FORK_ERR)
	{
		perror("Can't fork first child process.\n");
		return RET_ERR_FORK;
	}
	else if (childpid1 == FORK_OK)
	{
		printf("First child process: pid = %d, ppid = %d, pgrp = %d\n", 
				getpid(), getppid(), getpgrp());
		if (execl("./task3_sum", "task3_sum" , "2", "3", NULL) < 0)
		{
			perror("Can't execl from first child.\n");
			exit(RET_CANT_EXECLP);
		}
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
		if (execlp("cat", "cat", "for_cat.txt", NULL) < 0)
		{
			perror("Can't execlp from second child.\n");
			exit(RET_CANT_EXECLP);
		}
					
		exit(RET_OK);
	}

	sleep(INTERVAL);
	printf("Parent process: pid = %d, pgrp = %d, childpid1 = %d, childpid2 = %d\n", 
				getpid(), getpgrp(), childpid1, childpid2);
				
	int ch_status;
	for (int i = 0; i < 2; i++)
	{
		childpid = wait(&ch_status);
		printf("Child with pid = %d has finished with status %d\n", childpid, ch_status);
		
		if (WIFEXITED(ch_status))
			printf("Child exited normally with exit code %d\n", WEXITSTATUS(ch_status));
		else if (WIFSIGNALED(ch_status))
			printf("Child process ended with a non-intercepted signal number %d\n", WTERMSIG(ch_status));
		else if (WIFSTOPPED(ch_status))
			printf("Child process was stopped by a signal %d\n", WSTOPSIG(ch_status));
	}

	printf("Parent process is dead now\n");
	return RET_OK;
}
