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

#define INTERVAL 2
#define N_CHILDS 2

#define MSG1 "London is the capital of Great Britain\n"
#define LEN1 40
#define MSG2 "ABRA-kadabra\n"
#define LEN2 14
#define LENMAX 40

short flag_writing_allowed = 0;

void allow_writing(int signal)
{
	flag_writing_allowed = 1;
	printf("\nSignal %d was caught. Writing is allowed now.\n", signal);
} 

int main()
{
	pid_t childpid1, childpid2, childpid;
	int fd[2];
	
	// назначение обработчика сигнала
    signal(SIGINT, allow_writing);
	printf("Press \"CTRL+C\" to allow writing\n");
	sleep(INTERVAL);
	
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
		sleep(INTERVAL);
		printf("First child process: pid = %d, ppid = %d, pgrp = %d\n", 
		getpid(), getppid(), getpgrp());
		
		if (flag_writing_allowed)
		{
			close(fd[0]);
			write(fd[1], MSG1, strlen(MSG1) + 1);
			printf("Message from first child was sent\n"); 
		}
		else
		{
			printf("Writing to pipe for first child is not allowed\n");
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
		sleep(INTERVAL);
		printf("Second child process: pid = %d, ppid = %d, pgrp = %d\n", 
		getpid(), getppid(), getpgrp());
		
		if (flag_writing_allowed)
		{
			close(fd[0]);
			write(fd[1], MSG2, strlen(MSG2) + 1);
			printf("Message from second child was sent\n"); 
		}
		else
		{
			printf("Writing to pipe for second child is not allowed\n");
		}
		
		exit(RET_OK);
	}
	
	printf("Parent process: pid = %d, pgrp = %d, childpid1 = %d, childpid2 = %d\n", 
	getpid(), getpgrp(), childpid1, childpid2);
	
	sleep(INTERVAL);
	
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
	
	char message[LENMAX] = { 0 };
	
	printf("Reading messages from children.\n");
	close(fd[1]);
	
	if (read(fd[0], message, LEN1) < 0)
		printf("No messages from first child.\n");
	else
		printf("Message from first child:\n%s", message);
	
	if (read(fd[0], message, LEN2) < 0)
		printf("No messages from second child.\n");
	else
		printf("Message from second child:\n%s", message);
 
	printf("Parent process is dead now\n");
	return RET_OK;
}