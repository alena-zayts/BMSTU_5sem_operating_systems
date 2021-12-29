#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <wait.h>
#include <sys/shm.h>
#include <sys/sem.h>
#include <sys/stat.h>

#define N_ITERS 10

#define N_READERS 5
#define N_WRITERS 3

#define ACTIVE_READERS 0
#define CAN_WRITE 1
#define CAN_READ 2
#define WAITING_WRITERS 3

#define MIN_SLEEP 1
#define MAX_SLEEP 3


struct sembuf SEM_START_READ[] = 
{
	{WAITING_WRITERS, 0, 0},
    {CAN_READ, 0, 0},
    {ACTIVE_READERS, 1, 0},
};

struct sembuf SEM_STOP_READ[] = 
{
    {ACTIVE_READERS, -1, 0},
};

struct sembuf SEM_START_WRITE[] = 
{
    {WAITING_WRITERS, 1, 0},
    {ACTIVE_READERS, 0, 0},
    {CAN_WRITE, 0, 0},
    {CAN_WRITE, 1, 0},
	{CAN_READ, 1, 0},
    {WAITING_WRITERS, -1, 0},
};

struct sembuf SEM_STOP_WRITE[] = 
{
    {CAN_WRITE, -1, 0},
	{CAN_READ, -1, 0},
};

int start_read(int s_id)
{
    return semop(s_id, SEM_START_READ, 5) != -1;
}

int stop_read(int s_id)
{
    return semop(s_id, SEM_STOP_READ, 1) != -1;
}

int start_write(int s_id)
{
    return semop(s_id, SEM_START_WRITE, 5) != -1;
}

int stop_write(int s_id)
{
    return semop(s_id, SEM_STOP_WRITE, 1) != -1;
}

int reader_run(int *const shared_mem, const int s_id, const int reader_id)
{
    if (!shared_mem)
    {
        return 1;
    }

    srand(time(NULL) + reader_id);

    int sleep_time;

    for (size_t i = 0; i < N_ITERS; i++)
    {
        sleep_time = rand() % MAX_SLEEP + MIN_SLEEP;
        sleep(sleep_time);

        if (!start_read(s_id))
        {
            perror("Start reading error.");
            exit(1);
        }

        int val = *shared_mem;
        printf("                                  |"
			   "Reader %d read: %2d , sleep time=%d\n", reader_id, val, sleep_time);

        if (!stop_read(s_id))
        {
            perror("End reading error.");
            exit(1);
        }
    }

    return 0;
}

int writer_run(int *const shared_mem, const int s_id, const int writer_id)
{
    if (!shared_mem)
    {
        return 1;
    }

    srand(time(NULL) + writer_id + N_READERS);

    int sleep_time;

    for (size_t i = 0; i < N_ITERS; i++)
    {
        sleep_time = rand() % MAX_SLEEP + MIN_SLEEP;
        sleep(sleep_time);

        if (!start_write(s_id))
        {
            perror("Start writing error.");
            exit(1);
        }

        int val = ++(*shared_mem);
        printf("Writer %d wrote: %2d , sleep time=%d |\n", writer_id, val, sleep_time);

        if (!stop_write(s_id))
        {
            perror("End writing error.");
            exit(1);
        }
    }

    return 0;
}

int main()
{
    setbuf(stdout, NULL);
	
	int perms = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;

    int fd = shmget(IPC_PRIVATE, sizeof(int), perms | IPC_CREAT);
    if (fd == -1)
    {
        perror("shmget failed");
        return 1;
    }

    int *shared_mem = shmat(fd, 0, 0);
    if (shared_mem == (void *)-1)
    {
        perror("shmat failed");
        return 1;
    }

    int s_id = semget(IPC_PRIVATE, 4, perms | IPC_CREAT);
    if (s_id == -1)
    {
        perror("semget failed");
        return 1;
    }
	
	if (semctl(s_id, ACTIVE_READERS, SETVAL, 0) == -1 ||
        semctl(s_id, CAN_WRITE, SETVAL, 0) == -1 || 
        semctl(s_id, WAITING_WRITERS, SETVAL, 0) == -1 ||
		semctl(s_id, CAN_READ, SETVAL, 0) == -1
		)	
    {
        perror("sem initialization error");
        return 1;
    }


    for (size_t i = 0; i < N_READERS; i++)
    {
		int child_pid = fork();
		if (child_pid == -1) 
        {
            perror("Error: fork for reader");
            return 1;
        } 
        else if (child_pid  == 0) 
        {
            reader_run(shared_mem, s_id, i);
            return 0;
        }
    }

    for (size_t i = 0; i < N_WRITERS; ++i)
    {
		int child_pid = fork();
		if (child_pid == -1) 
        {
            perror("Error: fork for writer");
            return 1;
        } 
        else if (child_pid  == 0) 
        {
            writer_run(shared_mem, s_id, i);
            return 0;
        }
    }

    for (size_t i = 0; i < N_WRITERS + N_READERS; i++)
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

    if (shmdt(shared_mem) == -1)
    {
        perror("shmdt failed");
        return 1;
    }
	
    if (shmctl(fd, IPC_RMID, NULL) == -1) 
    {
        perror("shmctl with command IPC_RMID failed");
        return 1;
    }

    if (semctl(s_id, 0, IPC_RMID) == -1)
    {
        perror("semctl with command IPC_RMID failed");
        return 1;
    }
	

    return 0;
}