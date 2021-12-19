#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <windows.h>

#define N_READERS 5
#define N_WRITERS 3

#define N_ITERS 4

#define MIN_READER_SLEEP 300
#define MAX_READER_SLEEP 2000
#define MIN_WRITER_SLEEP 100
#define MAX_WRITER_SLEEP 1500


HANDLE mutex;
HANDLE can_read;
HANDLE can_write;

LONG waiting_writers_amount = 0;
LONG waiting_readers_amount = 0;
LONG active_readers_amount = 0;

bool active_writer = false;

int value = 0;

void start_read()
{
    InterlockedIncrement(&waiting_readers_amount);

    if (active_writer || (WaitForSingleObject(can_write, 0) == WAIT_OBJECT_0 && waiting_writers_amount))
    {
        WaitForSingleObject(can_read, INFINITE);
    }
	
    WaitForSingleObject(mutex, INFINITE);

    InterlockedDecrement(&waiting_readers_amount);
    InterlockedIncrement(&active_readers_amount);

    SetEvent(can_read);
    ReleaseMutex(mutex);
}

void stop_read()
{
    InterlockedDecrement(&active_readers_amount);

    if (active_readers_amount == 0)
    {
        ResetEvent(can_read);
        SetEvent(can_write);
    }
}

void start_write(void)
{
    InterlockedIncrement(&waiting_writers_amount);

    if (active_writer || active_readers_amount > 0)
    {
        WaitForSingleObject(can_write, INFINITE);
    }

    InterlockedDecrement(&waiting_writers_amount);

    active_writer = true;
}

void stop_write(void)
{
    active_writer = false;

    if (waiting_readers_amount)
    {
        SetEvent(can_read);
    }
    else
    {
        SetEvent(can_write);
    }
}

DWORD WINAPI reader_run(CONST LPVOID param)
{
    int reader_id = (int)param;
    srand(time(NULL) + reader_id);

    int sleep_time;

    for (size_t i = 0; i < N_ITERS; i++)
    {
        sleep_time = MIN_READER_SLEEP + rand() % (MAX_READER_SLEEP - MIN_READER_SLEEP);
        Sleep(sleep_time);
        start_read();
        printf("Reader %d read:  %3d || Sleep time: %dms\n", reader_id, value, sleep_time);
        stop_read();
    }

    return 0;
}

DWORD WINAPI writer_run(CONST LPVOID param)
{
    int writer_id = (int)param;
    srand(time(NULL) + writer_id + N_READERS);

    int sleep_time;

    for (size_t i = 0; i < N_ITERS; i++)
    {
        sleep_time = MIN_WRITER_SLEEP + rand() % (MAX_WRITER_SLEEP - MIN_WRITER_SLEEP);
        Sleep(sleep_time);
        start_write();
        ++value;
        printf("Writer %d wrote: %3d || Sleep time: %dms\n", writer_id, value, sleep_time);
        stop_write();
    }
    return 0;
}

int main()
{
    setbuf(stdout, NULL);

    HANDLE readers_threads[N_READERS];
    HANDLE writers_threads[N_WRITERS];

	//Процедура CreateMutex() создает новый мьютекс. 
	//О первом аргументе сейчас знать не нужно. 
	//второй аргумент равен FALSE, создается свободный мьютекс. 
	//Третий аргумент задает имя мьютекса
    if ((mutex = CreateMutex(NULL, FALSE, NULL)) == NULL)
    {
        perror("CreateMutex error");

        return -1;
    }

	//1 - не требуется задание особых прав доступа под Windows NT или возможности наследования объекта дочерними процессами
	//2 - переключаемым вручную (TRUE) или автоматически (FALSE)
	//3 - начальное состояние
	//4 - имя
	// Со сбросом вручную	Будучи установленным в сигнальное состояние, остается в нем до тех пор, пока не будет переключен явным вызовом функции ResetEvent
	// С автосбросом	Автоматически переключается в несигнальное состояние операционной системой, когда один из ожидающих его потоков завершается

    if ((can_read = CreateEvent(NULL, FALSE, FALSE, NULL)) == NULL)
	{
		perror("CreateEvent (can_read) error");
		return -1;
	}
	if ((can_write = CreateEvent(NULL, FALSE, FALSE, NULL)) == NULL)
    {
		perror("CreateEvent (can_write) error");
		return -1;
	}


    for (size_t i = 0; i < N_READERS; i++)
    {
		// Параметры слева направо:
		// NULL - Атрибуты защиты определены по умолчанию;
		// 0 - размер стека устанавливается по умолчанию;
		// reader_run - определяет адрес функции потока, с которой следует начать выполнение потока;
		// i - указатель на переменную, которая передается в поток;
		// 0 - исполнение потока начинается немедленно;
		// Последний - адрес переменной типа DWORD, в которую функция возвращает идентификатор потока.
        readers_threads[i] = CreateThread(NULL, 0, &reader_run, (LPVOID)i, 0, NULL);
        if (readers_threads[i] == NULL)
        {
            perror("CreateThread (reader) error");
            return -1;
        }
    }

    for (size_t i = 0; i < N_WRITERS; i++)
    {
        writers_threads[i] = CreateThread(NULL, 0, writer_run, (LPVOID)i, 0, NULL);
        if (writers_threads[i] == NULL)
        {
            perror("CreateThread (writer) error");
            return -1;
        }
    }

	// N_READERS - кол-во инетерсующих нас объектов ядра.
	// readers_threads - указатель на массив описателей объектов ядра.
	// TRUE - функция не даст потоку возобновить свою работу, пока не освободятся все объекты.
	// INFINITE - указывает, сколько времени поток готов ждать освобождения объекта.
    WaitForMultipleObjects(N_READERS, readers_threads, TRUE, INFINITE);
    WaitForMultipleObjects(N_WRITERS, writers_threads, TRUE, INFINITE);

    CloseHandle(mutex);
    CloseHandle(can_read);
    CloseHandle(can_write);
	
	for (size_t i = 0; i < N_READERS; i++)
		CloseHandle(readers_threads[i]);

	for (size_t i = 0; i < N_WRITERS; i++)
		CloseHandle(writers_threads[i]);

    return 0;
}