;16-разрядный сегмент кода, граница в байтах (G=0)(для реального режима) 
;32-разрядный (D=1) сегмент данных, размер: 4 Гб 	;(для определения объема выделенной памяти)
;32-разрядный (D=1) сегмент кода, граница в байтах (G=0) ;(для защищенного режима)
;32-разрядный (D=1) сегмент данных, граница в байтах (G=0) (от нас-там данные всякие, рязанова хотела 16-р)
;32-разрядный (D=1) сегмент стека, граница в байтах (G=0);(для прерываний в ЗР)
;видеобуфер (0,0)
	

;разрешение трансляции набора команд микропроцессора 80386, 
;часть которых отностится к привилегированным
.386p

;В РР сегменты определяются базовыми адресами, задаваемыми в явной форме, 
;В ЗР - дескриптором (8-байтовым полем)

;Формат дескриптора для GDT:

;Байты 2-3 (base_low), 4 (base_middle), 7 (base_heigh): база сегмента - 
;	начальный линейный адрес сегмента в адресном пространстве процессора 
;	(имеет длину 32 бита, номер байта, может располагаться в любом месте адр. 
;	пространства 4Гбайт). Если страничная адресация выключена, он совпадает с 
;	физическим (как в данной программе), включена - могут и не совпадать

;Байты 0-1 (limit): младшие 16 бит границы сегмента -номер последнего байта сегмента). 

;Байт 6: atrr_2:
;	Младшие 4 бита: оставшиеся старшие 4 бита границы сегмента (итого 20 бит).
;	7 бит (G бит дробности (гранулярности)): единицы, в которых задается граница.
;			0-в байтах (и тогда сегмент<=1 Mбайт),
;			1-в блоках по 4 Кбайт (страницах)(до 4 Гбайт) 
;			гр. сег.=гр.в.дескр.*4К+4095 - до конца последнего 4-Кбайтного блока).
;	6 бит (D default): разрядность операндов и адресов по умолчанию (1-32, 0-16)
;			Можно изменить на противоположный префиксом  замены размера 66h(операнда)
;			и 67h (адреса). D=0 не запрещает использовать 32 регистры: компилятор сам 
;			добавит перфикс

;Байт 5: attr_1:
;	0 бит (A accessed): устанавливаетсся процессором, когда в какой-либо сегментый регистр
;		загружается селектор данного сегмента (было обращение)
;	1-3 биты: тип сегмента. 
;		1 бит: Для кода [0–чтение из сегмента запрещено (не относится к выборке команд), 
;                 		 1 – разрешено] 
;       	   Для данных [0- модификации запрещены, 1-модификации разрешены]
;		2 бит: Для кода [бит подчинения: 0 – код подчинен (связан с каким –то другим сегментом),
;                                 		 1 – обычный]
;					Подчиненные, или согласованные сегменты обычно используются ддя хранения
;					подпроrрамм общего пользойаНия; для них не действуют общие правила защнты
;					проrрамм друг от друга. 
;       		Для стека и данных [0-данные, 1-стек]
;		3 бит – бит предназначения: 0 – сегмент данных/стека, 1-кода
;	4 бит (S system): идентификатор сегмента (0-системный сегмент, 1-сегмент памяти).
;	5-6 биты (DPL descriptor privilege level):  уровень привилегий этого дескриптора
;            от 0 (УП ядра системы) до 3 (УП приложений).
;	7 (P present): бит присутствия, представлен ли сегмент в памяти 

;Формат дескриптора (шлюза) для IDT:
;Байты 0-1 (offs_1), 6-7 (offs_2): 32-битное смещение обработчика
;Байты 2-3 (sel): селектор(сег. команд)(итого полный 3-хсловный адрес обработчика селектор: смещение)
;Байт 4 зарезервирован
;Байт 5: байт атрибутов - как в дескрипторах памяти за исключением типа:
;	1-3 биты: тип дескриптора. Может принимать 16 значений, но в IDT допустимо 5:
;	5(задачи), 6(прерываний 286), 7(ловушки 286), Eh(прерываний 3/486), Fh(ловушки 3/486)
;   через шлюзы прерываний обрабатываются аппаратные пр., ловушек-программные пр. и искл.


;Структура descr для описания дескрипторов сегментов
descr struc
    limit   dw 0
    base_l  dw 0
    base_m  db 0
    attr_1  db 0
    attr_2  db 0
    base_h  db 0
descr ends

;Структура idescr для описания дескрипторов (шлюзов) прерываний
idescr struc
    offs_l  dw 0
    sel     dw 0
    cntr    db 0
    attr    db 0
    offs_h  dw 0
idescr ends

;32-разрядный сегмент стека
stack32 segment  para stack 'STACK'
    stack_start db  100h dup(?)
    stack_size = $-stack_start
stack32 ends


;32-разрядный сегмент данных
data32 segment para 'data'
	; Таблица глобальных дескрипторов
	
	;Дескриптор: <limit, base_l, base_m, attr_1, attr_2, base_h>
	;Базы сегментов будут вычислены программно и занесены в соответсвующие
	;дескрипторы на этапе выполнения. Фактические значения размеров сегментов 
	;будут вычислены транслятором (если не указано конкретное значение в описании GDT)
	
	;в данной программе для сегмента команд attr_1=98h=10011000b:
	;	сегмент присутсвует в памяти, имеет УП ядра, является сегментом памяти, 
	;	подчиненный сегмент кода, разрешено только исполнение
	
	;для сегмента данных (или стека) attr_1=92h=10010010b:
	;	сегмент присутсвует в памяти, УП ядра, является сегментом памяти, 
	; 	сегмент данных, разрешены чтение и запись
	
	; Нулевой дескриптор
    gdt_null  descr <>
	
	;сегмент кода, разрешено только исполнение
	;G=0 (граница в байтах), D=0 (разрядность оп. и адр. по ум.16)
	;(для реального режима) 
    gdt_code16 descr <code16_size-1,0,0,98h>
	
	;размер: 4 Гб
	;сегмент данных, разрешены чтение и запись 
	;G=1 (граница в блоках по 4 Кбайт), D=1 (разрядность оп. и адр. по ум.32)
	;(для определения объема выделенной памяти)
    gdt_data4gb descr <0FFFFh,0,0,92h,0CFh>
	
	;сегмент кода, разрешено только исполнение
	;G=0 (граница в байтах), D=1 (разрядность оп. и адр. по ум.32)
	;(для защищенного режима)
    gdt_code32 descr <code32_size-1,0,0,98h,40h>
	
	;сегмент данных, разрешены чтение и запись 
	;G=0 (граница в байтах), D=1 (разрядность оп. и адр. по ум.32)
	;(?зачем)
    gdt_data32 descr <data_size-1,0,0,92h,40h>
	
	;сегмент данных (стек), разрешены чтение и запись 
	;G=0 (граница в байтах), D=1 (разрядность оп. и адр. по ум.32)
	;(для прерываний в ЗР)
    gdt_stack32 descr <stack_size-1,0,0,92h,40h>
	
	;видеобуфер
	;размер страницы=4096 байт, базовый физический адрес=B8000h
	;G=0 (граница в байтах), D=0 (разрядность оп. и адр. по ум.16)
    gdt_video16 descr <4095,8000h,0Bh,92h>

    gdt_size=$-gdt_null	;размер
    pdescr    df 0		;псевдодескриптор
	
	;Селекторы
    code16s=8
    data4gbs=16
    code32s=24
    data32s=32
    stack32s=40
    video16s=48

	;Таблица дескрипторов прерываний IDT
	;Дескриптор: <offs_l, sel, rsrv, attr, offs_h>
	;смещение позже?, селектор 32-разрядного сегмента кода 
    idt label byte

	; Первые 32 элемента таблицы - под исключения-внутренние прерывния процессора
	;(реально-18, остальные-зарезервированы)
	;attr=8Fh: тип=ловушка 386/486(обр. программные пр. и искл., IF не меняется), 
	;системный объект, УП ядра, P=1
    idescr_0_12 idescr 13 dup (<0,code32s,0,8Fh,0>)
	; исключение 13 - нарушение общей защиты (нарушение, код ошибки-та команда)
	; происходит: за пределами сегмента, запрет чтения, за гр. таблицы дескр., int с отс. номером
    idescr_13 idescr <0,code32s,0,8Fh,0>
    idescr_14_31 idescr 18 dup (<0,code32s,0,8Fh,0>)


	; Затем 16 векторов аппаратных прерываний, 		
	;attr=8Eh: тип=прерывание 386/486(обр. аппаратные пр., IF сбрасывается а iret восстанавливает), 
	;системный объект, УП ядра, P=1
	;Дескриптор прерывания от таймера
    int08 idescr <0,code32s,0,8Eh,0> 
    int09 idescr <0,code32s,0,8Eh,0>

    idt_size = $-idt  		;размер
    ipdescr df 0	  		;псевдодескриптор
    ipdescr16 dw 3FFh, 0, 0	;содержимое регистра IDTR в РР: с адреса 0, 256*4=1кб=2^10

	; Маски прерываний ведущего и ведомого контроллеров 1 вроде блокирует
    mask_master db 0        
    mask_slave  db 0        

	; Таблица символов ASCII для перевода из скан кода в код ASCII.
    asciimap   db 0, 0, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 0, 0
    db 81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 91, 93, 0, 0, 65, 83
    db 68, 70, 71, 72, 74, 75, 76, 59, 39, 96, 0, 92, 90, 88, 67
    db 86, 66, 78, 77, 44, 46, 47

    flag_enter_pr db 0	;флаг нажатия клавиши для перехода
    cnt_time      db 0  ;счетчик таймера       

    syml_pos      dd 2 * 80 * 5 ;куда выводить от клавиатуры

    interval=10

    pm_pos=0				
	pm_msg db 'Switched to protected mode. Press "Enter" to return...'
	
    mem_pos=80*2			
	mem_msg db 'Memory: '
    mem_value_pos=80*2+7*2	
    mb_pos=80*2+17*2					
    cursor_pos=80*2*3
    param db 34h  ;0 011 0 100  не мерцает, фон зеленый, яркий, символ красный
	param_8 db 34h

	cursor_symb db 'T'

	rm_msg_1 db 'Start in real mode', 13, 10, '$'
	rm_msg_wait db 'Press any key to enter protected mode...', 13, 10, '$'
	rm_msg_2 db 'Back in real mode', 13, 10, '$'

    data_size = $-gdt_null 
data32 ends

; 32-разрядный сегмент кода для защищенного режима
code32 segment para public 'code' use32
    assume cs:code32, ds:data32, ss:stack32

pm_start:
	;Загрузка в используемые сегментные регистры селекторов соответсвующих сегментов
    mov ax, data32s
    mov ds, ax
    mov ax, video16s
    mov es, ax
    mov ax, stack32s
    mov ss, ax
    mov eax, stack_size
    mov esp, eax

	; Резрешаем (аппаратные) прерывания
    sti 
	
	
	;вывод сообщения из ЗР 
	mov ecx, 54                   ;число выводимых символов
	mov ah, param                 ;аттрибут выводимых символов (ah не меняется)
 	mov esi, offset pm_msg 		  ;начало сообщения (si смещается)
	xor edi, edi
	mov di, pm_pos                ;начальное смещение на экране (di смещается)
print_pm:
	;LODSB копирует 1 байт из памяти по адресу DS:SI в регистр AL и изменяет SI
	lodsb
	;STOSW сохраняет регистр AX в ячейке памяти по адресу ES:DI и изменяет DI
 	stosw
    loop print_pm
	
	
    mov ecx, 7                  
	mov ah, param              
 	mov esi, offset mem_msg 	
	xor edi, edi
	mov di, mem_pos           
print_mem:
	lodsb
 	stosw
    loop print_mem

    call count_memory
	
	; Цикл, пока не будет введен Enter
    ; (Флаг flag_enter_pr выставляется в функции-обработчике нажатия
	; с клавиатуры при нажатии Enter'a)
    proccess:
        test flag_enter_pr, 1
        jz  proccess


	; Выход из защищенного режима
    cli ; Запрет аппаратных маскируемые прерывания прерываний. 

    db  0EAh
    dd  offset return_rm
    dw  code16s		;селектор

	; Зашлушка для исключений
    dummy_exc proc
        iret
    dummy_exc endp

	; Заглушка для 13 исключения.
	; исключение 13 - нарушение общей защиты (нарушение, есть код ошибки, команда обращения к памяти
	; происходит при обращении к сегменту по относительному адресу, выходящему за его пределы)
    ; Нужно снять со стека код ошибки.
    except_13 proc ;uses eax
        ;pop eax
		add ESP, 4 ;коррекция стека на поле кода ошибки
        iret
    except_13 endp


    new_int08 proc ;uses eax
		push eax
		        
		mov edi, cursor_pos ; поместим в edi позицию для вывода

        mov ah, param_8 ; В ah помещаем цвет текста.
        ror ah, 1           ; Сдвигаем циклически вправо параметр (он примет какое-то новое значение) 
        mov param_8, ah
        mov al, cursor_symb ; Символ, который мы хотим вывести 
        stosw ; al (символ) с параметром (ah) перемещается в область памяти es:di

        ; используется только в аппаратных прерываниях для корректного завершения
        ; (разрешаем обработку прерываний с меньшим приоритетом)!!
		;необходимо сбросить контроллер прерываний
        mov al, 20h
        out 20h, al
		
		pop eax
        iretd ; double - 32 битный iret
    new_int08 endp

	; Обработчик прерывания клавиатуры
    new_int09 proc ;uses eax ebx edx
		push eax
		push ebx
		push edx
		
		;Порт 60h при чтении содержит скан-код последней нажатой клавиши.
        in  al, 60h
        cmp al, 1Ch ; Сравниваем с кодом Enter

        jne print_value         
        or flag_enter_pr, 1		; если Enter, устанавливаем флаг
        jmp allow_handle_keyboard

    print_value:
		;(скан-код отпускания клавиши равен скан-коду нажатия плюс 80h)
		; ja:op1>op2, то есть переход, если скан-код сообщает об отпускании клавиши 
		
        cmp al, 80h  
        ja allow_handle_keyboard     

        xor ah, ah   
        xor ebx, ebx
        mov bx, ax

        mov dh, param
        mov dl, asciimap[ebx]   
        mov ebx, syml_pos   
        mov es:[ebx], dx

        add ebx, 2          
        mov syml_pos, ebx

    allow_handle_keyboard:
		;старший бит порта 61h = 1, клавиатура  заблокирована, 0 - разблокирована.
		;разблокировка клавиатуры
		in  al, 61h 
        or  al, 80h 
        out 61h, al 
		;сброс???
        ; and al, 7Fh 
        ; out 61h, al

		;необходимо сбросить контроллер прерываний
        mov al, 20h 
        out 20h, al
		
		pop edx
		pop ebx
		pop eax
        iretd
    new_int09 endp


    count_memory proc ;uses fs eax ebx
		push fs
		push eax
		push ebx
		
        mov ax, data4gbs
        mov fs, ax

		; Перепрыгиваем первый мегабайт 2^20.
        ; Т.к в первом мегобайте располагается наша программа
		; Счетчик (кол-во памяти).
		; (16^5 + 1 = 2^20 + 1) байт. (можно не делать +1, 
		; первый мегабайт начинается с байта с индексом 2^20)
        mov ebx,  100001h
		; Некоторое значение, с помощью которого мы будем проверять запись.
        mov dl,   0AEh
		; Это оставшееся FFEF FFFE + 10 0001 = F0000 0000 ==  (2^4)^8 = 2^32  = 4 Гб
        mov ecx, 0FFEFFFFEh

        iterate_through_memory:
            mov dh, fs:[ebx] ; Сохраняем байт в dh.
            mov fs:[ebx], dl ; Записываем по этому адресу сигнатуру.      
            cmp fs:[ebx], dl ; Сравниваем записанную сигнатуру с сигнатурой в программе.	       
            jnz print_memory_counter     ; Если не равны, то это уже не наша память. Выводим посчитанное кол-во.   

            mov fs:[ebx], dh 
            inc ebx
        loop iterate_through_memory

    print_memory_counter:
		; Переводим память из ebx из байтов в мегабайты.
		; Делим на 2^20 (количество байт в мегабайте).
        mov eax, ebx 
        xor edx, edx

        mov ebx, 100000h
        div ebx

        mov ebx, mem_value_pos
        call print_eax


        mov ah, param
        mov ebx, mb_pos
        mov al, 'M'
        mov es:[ebx], ax

        mov ebx, mb_pos + 2
        mov al, 'b'
        mov es:[ebx], ax
		
		pop ebx 
		pop eax
		pop fs
        ret
    count_memory endp



    print_eax proc ;uses ecx ebx edx
		push ecx
		push ebx
		push edx
		
		; почему именно 8?
		; сдвигаем ebx на 8 позиций (будем печатать 8 символов) и устанавливаем счетчик
        add ebx, 10h
        mov ecx, 8
        mov dh, param

        print_symbol:
			; Получаем "младшую часть dl"
			; AND с 0000 1111 --> остаются последние 4 бита, то есть 16ричная цифра
            mov dl, al
            and dl, 0Fh
			
			; Если dl меньше 10, то выводим просто эту цифру.
            cmp dl, 10
            jl print_hex_digit
            add dl, 'A' - 10 - '0'

        print_hex_digit:
            add dl, '0' 
            mov es:[ebx], dx 
			; Циклически сдвигаем вправо число на 4, 
            ; Тем самым на след. операции будем работать со след. цифрой.
            ror eax, 4       
			; переходим к левой ячейки видеопамяти  	
            sub ebx, 2       
        loop print_symbol
		
		pop edx 
		pop ebx
		pop ecx
		
        ret
    print_eax endp

    code32_size = $-pm_start
code32 ends

;16-разрядный сегмент кода для реального режима
code16 segment para public 'CODE' use16
assume cs:code16, ds:data32, ss: stack32
start:
    mov ax, data32
    mov ds, ax

    mov ah, 09h
    lea dx, rm_msg_1
    int 21h

    mov ah, 09h
    lea dx, rm_msg_wait
    int 21h

    ;ожидание нажатия клавиши для перехода
	; INT 16H: сервис клавиатуры. ah=10h Читать буфер клавиатуры
	; Ждёт нажатия, если клавиша не нажата, и потом выдаёт нажатую клавишу
    mov ah, 10h
    int 16h

    ; очистка экрана
    mov ax, 3
    int 10h


	;Завершение формирования дескрипторов сегментов программы заполнением 
	;базовых адресов сегментов. Линейные 32-битовые адреса определяются путем
	;умножения значений сегментных адресов на 16 (=побитовый сдвиг влево на 4)
	;SHL и ROL - логический и циклический побитовые сдвиги op1 влево на op2 бит, соответственно
	;(rol на 16 фактически обменивает местами старшую и младщую половины)
    xor eax, eax
	
    mov ax, code16
    shl eax, 4 								                
    mov word ptr gdt_code16.base_l, ax  
	rol eax, 16	 
	mov byte ptr gdt_code16.base_m, al  

    mov ax, code32
    shl eax, 4                        
    mov word ptr gdt_code32.base_l, ax  
    rol eax, 16                       
    mov byte ptr gdt_code32.base_m, al  

    mov ax, data32
    shl eax, 4 
	mov ebp, eax ;на будущее
    mov word ptr gdt_data32.base_l, ax  
    rol eax, 16                       
    mov byte ptr gdt_data32.base_m, al   

    mov ax, stack32
    shl eax, 4                        
    mov word ptr gdt_stack32.base_l, ax  
    rol eax, 16                       
    mov byte ptr gdt_stack32.base_m, al  

	;Подготовка и загрузка в GDTR псевдодескриптора - 6-байтного поля данных, куда 
	;записывается информация о GDT: ее линейный базовый адрес (2-5) и размер (0-1)
	;GDT расположена в начале сегмента данных, базовый адрес которого хранится в ebp 
    ; Коварный вопрос: размер GDTR? - 32 бита (4 байта) по мнению Рязановой
    ; В Зубкове на стр 477 написано, что он 48 битный (6 байт)
    ; LGDT (Load GDT) - загружает в регистр процессора GDTR (GDT Register)  (лежит лин. адр этой табл и размер)
    ; (LGDT относится к типу привилегированных команд.)
    ; Вызываем ее в р-р.fword=6 байт
    ; Это говорит нам о том, что в р-р нет никакой защиты.	
    mov dword ptr pdescr+2, ebp
    mov word ptr  pdescr, gdt_size-1  
    lgdt fword ptr pdescr    ; специальная привилеrированная команда, заrрузка таблицы GDT         


	; Заносим в дескрипторы прерываний (шлюзы) смешение обработчиков прерываний.
    lea eax, es:dummy_exc
    mov idescr_0_12.offs_l, ax 
    shr eax, 16             
    mov idescr_0_12.offs_h, ax 

    lea eax, es:except_13
    mov idescr_13.offs_l, ax 
    shr eax, 16             
    mov idescr_13.offs_h, ax 

    lea eax, es:dummy_exc
    mov idescr_14_31.offs_l, ax 
    shr eax, 16             
    mov idescr_14_31.offs_h, ax 


    lea eax, es:new_int08
    mov int08.offs_l, ax
    shr eax, 16
    mov int08.offs_h, ax

    lea eax, es:new_int09
    mov int09.offs_l, ax 
    shr eax, 16             
    mov int09.offs_h, ax 

	;Подготовка и загрузка в IDTR псевдодескриптора 
    mov ax, data32
    shl eax, 4
    add eax, offset idt	;линейный базовый адрес

    mov  dword ptr ipdescr + 2, eax 
    mov  word ptr  ipdescr, idt_size-1 


    ; Сохранение масок (см. сем) (Чтобы смогли их восстановить)
	; После сброса BIOS реинициализирует контроллеры прерываний. 
	; При этом в обоих контроллерах устанавливаются значения масок прерываний FFh, т.е. 
	; все прерывания оказываются замаскированными. Поэrому сразу же ПOCJte перехода в
	;реальный режим следует установить правильные значения
	;Конкретные значения зависят от конфигурации компьютера, определяем командой ввода из порта
	
	;порты 20h, 21h-ведущий; A0h, A1h-ведомый
    in  al, 21h                     
    mov mask_master, al             
    in  al, 0A1h                    
    mov mask_slave, al
	

    ;перепрограммирование ведущего контроллера, т.к. в ЗР первые 32 вектора зарезервированны 
	;для обработки исключений, аппаратным прерываниям нужно назначить другие векторы 32=20h
	;Для смены базового веткора требуется полностью выполнить процедуру инициализации контр.
	;которая состоит из ряда команд инициализации СКИ
    mov al, 11h	;СКИ1: два контроллера в компьютере, будет СКИ3
    out 20h, al                  
    mov al, 32	;СКИ2: базовый вектор (был 8)
    out 21h, al                  
    mov al, 4	;СКИ3: ведомый подключен к уровню 2
    out 21h, al
    mov al, 1	;СКИ4:8086, требуется EOI программно
    out 21h, al

	;установка маски прерываний. 
    ; маска для ведущего контроллера - запрещаем все прерывания, 
	; кроме прерывания от таймера (0) и клавиатуры (1)
	; (разрешаем только IRQ0 И IRQ1 (Interruption Request - Запрос прерывания))
    mov al, 0FCh ;=1111 1100 
    out 21h, al

    ; маска для ведомого контроллера - запрещаем все прерывания
    mov al, 0FFh
    out 0A1h, al	

    lidt fword ptr ipdescr                                    

    ; открытие линии А20
	;Перед переходом в защищенный режим (или после перехода в нею) следует открыть линию А20, 
	;т.е. адресную линию, на которой устанавливается единичный уровень сигнала, если 
	;происходит обращение к мегабайтам адресною пространства с номерами l, 3, 5 и т.д. 
	;(первый мегабайт имеет номер 0). В реальном режиме линия А20 заблокирована, 
	;и есели значение адреса выходит за пределы FFFFFh, выполняется его циклическое 
	;оборачивание (линейный адрес lOOOOOh превращается в OOOOOh, адресс lOOOOlh в 00001h и т.д.). 
	;открытие (разблокирование) линии А20 выключает механизм циклическою оборачивания адреса, что 
	;позволяет адресоваться к расширенной nамяти. Управление блокированием линии А20 
	;осуществляется через порт 64h, куда сначала едедует послать команду Dlh 
	;управления линией А20, а затем - код открытия (DFh).
	;За вентиль линии A20 отвечает 1-й разряд порта; остальные разряды изменять нельзя.
    in  al, 92h
    or  al, 2
    out 92h, al
	
	;Запрет аппаратных прерываний 
    cli
	;Запрет немаскируемых прерываний, которые поступают в процессор по отдельной
	;линии (вход NMI микропроцессора) и не управляются битом IF. Специальной
	;команды нет, запрет установкой старшего бита (80h) в адресном порте 70h КМОП микросхемы.
	;?в учбенике 8F
	;mov al, 80h надо ли?
	;out 70h, al

	;Перевод процессора в ЗР установкой нулевого бита (PE) слова состояния машины
    mov eax, cr0
    or eax, 1     
    mov cr0, eax

	;Теперь процессор работает в ЗР
	;Загрузка в CS:IP селектор:смещение точки continue и очищение очереди команд
	;искусственно сконструированной командой дальнего перехода, которая
	;приводит к смене содержимого и IP, и CS, и очищает очередь предвыборки
    ; Префикс 66h - говорит нам о том, что
    ; След. команда будет разрядностью, противоложной нашего сегмента (use16)      
    db  66h 
    db  0EAh			; Код команды far jmp.
    dd  offset pm_start ; Смещение
    dw  code32s			; Селектор


return_rm:
	;Перевод процессора в РР сбросом нулевого бита PE слова состояния машины
    mov eax, cr0
    and al, 0FEh                
    mov cr0, eax

	;Загрузка в CS:IP сегмент:смещение точки return и очищение очереди команд
	;искусственно сконструированной командой дальнего перехода
    db  0EAh    
    dw  offset go
    dw  code16		;базовый адрес сегмента команд
	;теперь процессор снова работает в РР

go:
	;Восстановление операционной среды РР загрузкой в используемые далее
	;сегментные регистры соответствующих сегментных адресов
    mov ax, data32   
    mov ds, ax
    mov ax, code32
    mov es, ax
    mov ax, stack32   
    mov ss, ax
    mov ax, stack_size
    mov sp, ax

	; возвращаем базовый вектор контроллера прерываний
    mov al, 11h;СКИ1: два контроллера в компьютере, будет СКИ3
    out 20h, al
    mov al, 8	;СКИ2: базовый вектор (снова 8, был 32)
    out 21h, al
    mov al, 4   ;СКИ3: ведомый подключен к уровню 2
    out 21h, al
    mov al, 1   ;СКИ4:8086, требуется EOI программно
    out 21h, al

	; восстанавливаем маски контроллеров прерываний
    mov al, mask_master
    out 21h, al
    mov al, mask_slave
    out 0A1h, al

	; восстанавливаем IDTR (на 1ый кб)
    lidt    fword ptr ipdescr16

    ; закрытие линии A20 (если не закроем, то сможем адресовать еще 64кб памяти 
    in  al, 70h 
    and al, 7Fh
    out 70h, al
	
	;разрешение аппаратных и немаскируемых прерывний
	sti
	;mov AL, 0 	надо ли?
	;out 70h, AL

    ; Очищаем экран
    mov ax, 3
    int 10h

    mov ah, 09h
    lea dx, rm_msg_2
    int 21h

	;завершение программы (4сh) с кодом 0
    mov ax, 4C00h
    int 21h

    code16_size = $-start  
code16 ends

end start