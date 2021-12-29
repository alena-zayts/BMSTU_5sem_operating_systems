#include <stdio.h> 
#include <sys/shm.h>
#include <sys/stat.h> 
#include <sys/sem.h> 
#include <wait.h>

#include <time.h>
#include <stdlib.h> 
#include <unistd.h> 
#include <string.h>

#define N_PROD 3
#define N_CONS 3
#define N_WORKS 4

#define BIN_SEM_I 0
#define BUF_FULL_I 1
#define BUF_EMPTY_I 2

#define PROD_SLEEP_MIN 1
#define PROD_SLEEP_MAX 4

#define CONS_SLEEP_MIN 1
#define CONS_SLEEP_MAX 7


char *alphabet = "abcdefghijklmnopqrstuvwxyz";

typedef struct
{
    size_t prod_pos;
	size_t cons_pos;
    char buffer[N_WORKS];
} buf_struct;

	
struct sembuf PROD_LOCK[2] = {{BUF_EMPTY_I, -1, 0}, {BIN_SEM_I, -1, 0}};
struct sembuf PROD_RELEASE[2] = {{BUF_FULL_I, 1, 0}, {BIN_SEM_I, 1, 0}};

struct sembuf CONS_LOCK[2] = {{BUF_FULL_I, -1, 0}, {BIN_SEM_I, -1, 0}};
struct sembuf CONS_RELEASE[2] = {{BUF_EMPTY_I, 1, 0}, {BIN_SEM_I, 1, 0}};



int producer_run(buf_struct* const buf_t, const int sid, const int prodid) 
{
    srand(time(NULL) + prodid);

    if (!buf_t) 
	{
		perror("Producer buf_t error.");
        return 1;
    }

    for (size_t i = 0; i < N_WORKS; i++) 
	{
        int sleep_time = rand() % PROD_SLEEP_MAX + PROD_SLEEP_MIN;
        sleep(sleep_time);

        if (semop(sid, PROD_LOCK, 2) == -1) 
		{
			perror("Producer lock error.");
            return 1;
        }

        const char symb = alphabet[buf_t->prod_pos % strlen(alphabet)];
        buf_t->buffer[buf_t->prod_pos++] = symb;

        fprintf(stdout, "Producer %d wrote: %c , sleep time=%d |\n", prodid + 1, symb, sleep_time);

        if (semop(sid, PROD_RELEASE, 2) == -1) 
		{
			perror("Producer release error.");
            return 1;
        }
    }

    return 0;
}

int consumer_run(buf_struct* const buf_t, const int sid, const int consid) 
{
    srand(time(NULL) + consid + N_PROD);

    if (!buf_t) 
	{
		perror("Consumer buf_t error.");
        return 1;
    }

    for (int i = 0; i < N_WORKS; i++) 
	{
        int sleep_time = rand() % CONS_SLEEP_MAX + CONS_SLEEP_MIN;
        sleep(sleep_time);

        if (semop(sid, CONS_LOCK, 2) == -1) 
		{
			perror("Consumer lock error.");
            return 1;
        }

        char symb = buf_t->buffer[buf_t->cons_pos++];
		

        fprintf(stdout, "                                   ");
        fprintf(stdout, "| Consumer %d read: %c, sleep time=%d\n", consid + 1, symb, sleep_time);

        if (semop(sid, CONS_RELEASE, 2) == -1) 
		{
			perror("Consumer release error.");
            return 1;
        }
    }

    return 0;
}


int main() 
{
    setbuf(stdout, NULL);
    int perms = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
	
    int fd = shmget(IPC_PRIVATE, sizeof(buf_struct), perms | IPC_CREAT);
    if (fd == -1) 
    {
        perror("shmget failed");
        return 1;
    }
	
    buf_struct* buf_t = shmat(fd, 0, 0);
    if (buf_t == (void*) - 1) 
    {
        perror("shmat failed");
        return 1;
    }

    int isem_descr = semget(IPC_PRIVATE, 3, perms | IPC_CREAT);
    if (isem_descr == -1)
    {
        perror("semget failed");
        return 1;
    }
	
    if (semctl(isem_descr, BIN_SEM_I, SETVAL, 1) == -1 ||
        semctl(isem_descr, BUF_EMPTY_I, SETVAL, N_WORKS) == -1 || 
        semctl(isem_descr, BUF_FULL_I, SETVAL, 0) == -1)	
    {
        perror("sem initialization error");
        return 1;
    }

    for (size_t i = 0; i < N_PROD; i++) 
	{
        int child_pid = fork();

        if (child_pid == -1) 
        {
            perror("Error: fork for producer");
            return 1;
        } 
        else if (child_pid  == 0) 
        {
            producer_run(buf_t, isem_descr, i);
            return 0;
        }
    }

    for (size_t i = 0; i < N_CONS; i++) 
	{
        int child_pid = fork();

        if (child_pid == -1) 
        {
            perror("Error: fork for consumer");
            return 1;
        } 
        else if (child_pid == 0) 
        {
            consumer_run(buf_t, isem_descr, i);
            return 0;
        }
    }

    for (size_t i = 0; i < N_PROD + N_CONS; i++) 
	{
        int ch_status;
        int child_pid = wait(&ch_status);
        
        if (child_pid == -1)
        {
            perror("wait error");
            return 1;
        }

        if (!WIFEXITED(ch_status)) 
        {
            fprintf(stderr, "Child process %d terminated abnormally", child_pid);
        }
    }

    if (shmdt(buf_t) == -1)
    {
        perror("shmdt failed");
        return 1;
    }
	

    if (shmctl(fd, IPC_RMID, NULL) == -1) 
    {
        perror("shmctl with command IPC_RMID failed");
        return 1;
    }

    if (semctl(isem_descr, 0, IPC_RMID) == -1)
    {
        perror("semctl with command IPC_RMID failed");
        return 1;
    }


    return 0;
}