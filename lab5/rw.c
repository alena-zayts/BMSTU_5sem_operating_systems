#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <wait.h>
#include <sys/shm.h>
#include <sys/sem.h>
#include <sys/stat.h>

#define MAX_SEMS 4
#define ITERS 20

#define READERS_COUNT 5
#define WRITERS_COUNT 3

#define ACTIVE_READERS 0
#define ACTIVE_WRITERS 1

#define WAITING_READERS 2
#define WAITING_WRITERS 3

#define MAX_RAND 3

struct sembuf START_READ[] = {
    {WAITING_READERS, 1, 0},
    {ACTIVE_WRITERS, 0, 0},
    {WAITING_WRITERS, 0, 0},
    {ACTIVE_READERS, 1, 0},
    {WAITING_READERS, -1, 0},
};

struct sembuf STOP_READ[] = {
    {ACTIVE_READERS, -1, 0},
};

struct sembuf START_WRITE[] = {
    {WAITING_WRITERS, 1, 0},
    {ACTIVE_READERS, 0, 0},
    {ACTIVE_WRITERS, 0, 0},
    {ACTIVE_WRITERS, 1, 0},
    {WAITING_WRITERS, -1, 0},
};

struct sembuf STOP_WRITE[] = {
    {ACTIVE_WRITERS, -1, 0},
};

int start_read(int s_id)
{
    return semop(s_id, START_READ, 5) != -1;
}

int stop_read(int s_id)
{
    return semop(s_id, STOP_READ, 1) != -1;
}

int start_write(int s_id)
{
    return semop(s_id, START_WRITE, 5) != -1;
}

int stop_write(int s_id)
{
    return semop(s_id, STOP_WRITE, 1) != -1;
}

int rr_run(int *const shcntr, const int s_id, const int r_id)
{
    if (!shcntr)
    {
        return -1;
    }

    srand(time(NULL) + r_id);

    int stime;

    for (size_t i = 0; i < ITERS; ++i)
    {
        stime = rand() % MAX_RAND + 1;
        sleep(stime);

        if (!start_read(s_id))
        {
            perror("Reading start error.");

            exit(EXIT_FAILURE);
        }

        int val = *shcntr;
        printf("?Reader #%d read:  %3d // Idle time: %ds\n", r_id, val, stime);

        if (!stop_read(s_id))
        {
            perror("Reading end error.");

            exit(EXIT_FAILURE);
        }
    }

    return EXIT_SUCCESS;
}

int wr_run(int *const shcntr, const int s_id, const int w_id)
{
    if (!shcntr)
    {
        return -1;
    }

    srand(time(NULL) + w_id + READERS_COUNT);

    int stime;

    for (size_t i = 0; i < ITERS; ++i)
    {
        stime = rand() % MAX_RAND + 1;
        sleep(stime);

        if (!start_write(s_id))
        {
            perror("Writing start error.");

            exit(EXIT_FAILURE);
        }

        int val = ++(*shcntr);
        printf("!Writer #%d wrote: %3d // Idle time: %ds\n", w_id, val, stime);

        if (!stop_write(s_id))
        {
            perror("Writing end error.");

            exit(EXIT_FAILURE);
        }
    }

    return EXIT_SUCCESS;
}

int main()
{
    setbuf(stdout, NULL);

    int fd = shmget(IPC_PRIVATE, sizeof(int), IPC_CREAT | S_IRWXU | S_IRWXG | S_IRWXO);
    if (fd == -1)
    {
        perror("shmget failed.");

        return EXIT_FAILURE;
    }

    int *shcntr = shmat(fd, 0, 0);
    if (shcntr == (void *)-1)
    {
        perror("shmat failed.");

        return EXIT_FAILURE;
    }

    int s_id = semget(IPC_PRIVATE, MAX_SEMS, IPC_CREAT | S_IRWXU | S_IRWXG | S_IRWXO);
    if (s_id == -1)
    {
        perror("semget failed.");

        return EXIT_FAILURE;
    }

    semctl(s_id, ACTIVE_READERS, SETVAL, 0);
    semctl(s_id, ACTIVE_WRITERS, SETVAL, 0);
    semctl(s_id, WAITING_WRITERS, SETVAL, 0);
    semctl(s_id, WAITING_READERS, SETVAL, 0);

    int chpid;
    for (size_t i = 0; i < READERS_COUNT; ++i)
    {
        switch ((chpid = fork()))
        {
        case -1:
            perror("Reader fork failed.");

            exit(EXIT_FAILURE);
            break;
        case 0:
            rr_run(shcntr, s_id, i);

            return EXIT_SUCCESS;
        }
    }

    for (size_t i = 0; i < WRITERS_COUNT; ++i)
    {
        switch ((chpid = fork()))
        {
        case -1:
            perror("Writer fork failed.");

            exit(EXIT_FAILURE);
            break;
        case 0:
            wr_run(shcntr, s_id, i);

            return EXIT_SUCCESS;
        }
    }

    for (size_t i = 0; i < WRITERS_COUNT + READERS_COUNT; ++i)
    {
        int status;
        if (wait(&status) == -1)
        {
            perror("Child error.");

            exit(EXIT_FAILURE);
        }
        if (!WIFEXITED(status))
        {
            printf("Child process terminated abnormally\n");
        }
    }

    if (shmdt((void *)shcntr) == -1 ||
        shmctl(fd, IPC_RMID, NULL) == -1 ||
        semctl(s_id, IPC_RMID, 0) == -1)
    {

        perror("Exit error.");

        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}