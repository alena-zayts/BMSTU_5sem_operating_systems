#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>

#define RET_OK 0
#define RET_ERR_FORK 1
#define RET_ERR_PIPE 2

#define FORK_OK 0
#define FORK_ERR -1

#define BIG_INTERVAL 1000
#define SMALL_INTERVAL 800
#define N_CHILDS 2
#define MSG1 "This is message from 1 child\n"
#define MSG2 "This is message from 2 child\n"
#define LEN12 30

void child1_exit(int sig_numb) 
{
    printf("First child exits\n");
    exit(RET_OK);
}

void child2_exit(int sig_numb) 
{
    printf("Second child exits\n");
    exit(RET_OK);
}


int main()
{
	pid_t childpid1, childpid2, childpid;
	int fd[2];
	
	// назначение обработчиков сигнала
    signal(SIGUSR1, child1_exit);
	signal(SIGUSR2, child2_exit);
	
	if (pipe(fd) == -1)
	{
		perror("Can't pipe\n");
		return RET_ERR_PIPE;
	}


	if ((childpid1 = fork()) == FORK_ERR)
	{
		perror("Can't fork first child process.\n");
		return RET_ERR_FORK;
	}
	else if (childpid1 == FORK_OK)
	{
		printf("First child process: pid = %d, ppid = %d, pgrp = %d\n", 
		getpid(), getppid(), getpgrp());
		
		close(fd[0]);
		write(fd[1], MSG1, strlen(MSG1) + 1);
		printf("Message from first child was sent\n"); 
		
		while (1)
		{
			printf("First child in infinite loop\n"); 
			usleep(SMALL_INTERVAL);
		}
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
		
		close(fd[0]);
		write(fd[1], MSG2, strlen(MSG2) + 1);
		printf("Message from second child was sent\n"); 
		
		while (1)
		{
			printf("Second child in infinite loop\n"); 
			usleep(SMALL_INTERVAL);
		}
	}
	
	usleep(BIG_INTERVAL);
	printf("Parent process: pid = %d, pgrp = %d, childpid1 = %d, childpid2 = %d\n", 
	getpid(), getpgrp(), childpid1, childpid2);
	
	usleep(BIG_INTERVAL);
	
	printf("Parent sends signals to stop\n"); 
	kill(childpid1, SIGUSR1);
	kill(childpid2, SIGUSR2);

	int ch_status;
	for (int i = 0; i < N_CHILDS; i++)
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
	
	char message[LEN12] = { 0 };
	
	printf("\nReading messages from children.\n");
	close(fd[1]);
	
	for (int i = 0; i < N_CHILDS; i++)
	{
		
		if (read(fd[0], message, LEN12) < 0)
			printf("No messages from child %d.\n", i+1);
		else
			printf("Message from child %d:\n%s", i+1, message);
	}
 
	printf("Parent process is dead now\n");
	return RET_OK;
}