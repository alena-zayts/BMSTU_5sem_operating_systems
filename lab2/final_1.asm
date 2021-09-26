;разрегение трансляции набора команд микропроцессора 80386, 
;часть которых отностится к привилегированным
.386P

;В РР сегменты определяются базовыми адресами, задаваемыми в явной форме, 
;В ЗР - дескриптором (8-байтовым полем, в котором записываются базовый адрес
;сегмента, его длина и некоторые другие характеристики.

;В байтах 2-3 (base_low), 4 (base_middle), 7 (base_heigh) записывается база
;сегмента: начальный линейный адрес сегмента в адресном пространстве процессора 
;(имеет длину 32 бита, номер байта, может располагаться в любом месте адр. 
;пространства 4Гбайт). Если страничная адресация выкллючена, он совпадает с 
;физическим (как в данной программе), включена - могут и не совпадать

;В байах 0-1 (limit) записываются младшие 16 бит границы сегмента (номер 
;последнего байта сегмента). В младшие 4 бита байта атрибутов 2 записываются
;оставшиеся старшие 4 бита границы сегмента (итого 20 бит).

;С помощью бита дробности (гранулярности) G (7 бит байта атрибутов 2) можно 
;задавать единицы, в которых задается граница: 0-в байтах (и тогда сегмент<=1 Mбайт),
;1-в блоках по 4 Кбайт (страницах)(до 4 Гбайт) 
;(гр. сег.=гр.в дескр.*4К+4095 - до конца последнего 4-Кбайтного блока).


;В байтах 5, 6 записываются байты атрибутов (att1, att2 соответственно). 

;att2: 6 бит D (default (РФ)) определяет разрядность операндов и адресов (1-32, 0-16)
;Если компилятор встретит 32 разрядный операнд, он добавит к команде префикс замены
;размера операнда 66h).

;att1:
;младшие 4 бита (или 1-3) - тип сегмента. 
;0-A (accessed) устанавливаетсся процессором, когда в какой-либо сегментый регистр
;               закружается селектор данного сегмента (было обращение)
;1 бит: Для кода [0–чтение из сегмента запрещено (не относится к выборке команд), 
;                 1 – разрешено] 
;       Для данных [0- модификации разрешены, 
;                   1-модификации запрещены]
;2 бит: Для кода [бит подчинения: 0 – код подчинен (связан с каким –то другим сегментом),
;                                  1 – обычный]
;       Для стека и данных [0-данные, 1-стек]
;3 бит – бит предназначения: 0 – сегмент данных/стека, 1-кода
;Бит 4 - S system идентификатор сегмента (0-системный сегмент, 1-обычный (памяти)).
;Биты 5-6 - DPL descriptor privilege level - уровень привилегий этого дескриптора
;            от 0 (УП ядра системы) до 3 (УП приложений).
; Бит 7 - P present - бит присутствия, представлен ли сегмент в памяти 
; в данной программе attr_1=98h для сегмента команд, attr_1=92h для сегмента данных (или стека)

;Структура descr для описания дескрипторов сегментов (шаблон)
descr struc
limit dw 0
base_l dw 0
base_m db 0
attr_1 db 0
attr_2 db 0
base_h db 0
descr ends


;СЕГМЕНТ ДАННЫХ
;use16 объявляет, что по умолчанию в этом сегменте будут использоваться 16-битовые
;адреса и опреанды (что не запрещает использование 32-битовых регистров)
data segment use16

;Описание GDT
;селектор 0, обязательный нулевой дескриптор
gdt_null descr <0,0,0,0,0,0>
;селектор 8, сегмент данных
gdt_data descr <data_size-1,0,0,92h, 0, 0>
;селектор 16, сегмент команд
gdt_code descr <code_size-1,0,0,98h,0,0>
;селектор 24, сегмент стека
gdt_stack descr <255,0,0,92h, 0,0>
;селектор 32, видеобуфер
gdt_screen descr <4095,8000h,0Bh,92h,0,0>

;размер GDT
gdt_size=$-gdt_null


;поля данных программы
;псевдодескриптор для команды lgdt
pdescr dq 0	
;атрибут выводимых символов
attr db 34h  ;0 011 0 100  не мерцает, фон зеленый, яркий, символ красный
;сообщения о переключении между режимами
;13, 10 - комбинация возврата каретки и символа новой строки
msg_real_mode1 db 'start in real mode', 13, 10, '$'
msg_real_mode2 db 'end in real mode', 13, 10, '$'
msg_prot_mode db 'switched to protected mode'

;размер сегмента данных
data_size=$-gdt_null  
data ends


;СЕГМЕНТ КОМАНД
text segment 'code' use16
	assume CS:text, DS:data
main proc
	;Инициализация сегментных регистров, которая позволит в РР обращаться к сегментам.
	;Завершение формирования дескрипторов сегментов программы заполнением 
	;базовых адресов сегментов. Базовые 32-битовые адреса определяются путем
	;умножения значений сегментных адресов на 16 (=побитовый сдвиг влево на 4)
	;SHL и ROL - логический и циклический побитовые сдвиги op1 влево на op2 бит, соответственно
	;Занесение вычисленного адреса в соответсвующие дескрипторы
	
	;сегмент данных
	xor eax, eax
	mov AX, data
	mov DS, AX
	
	shl eax, 4
	mov ebp, eax
	mov bx, offset gdt_data
	mov [bx].base_l, ax
	rol eax, 16
	mov [bx].base_m, al
	
	;сегмент команд
	xor eax, eax
	mov ax, cs
	shl eax, 4
	mov bx, offset gdt_code
	mov [bx].base_l, ax
	rol eax, 16
	mov [bx].base_m, al
	
	;сегмент стека
	xor eax, eax
	mov ax, ss
	shl eax, 4
	mov bx, offset gdt_stack
	mov [bx].base_l, ax
	rol eax, 16
	mov [bx].base_m, al
	;работа программы до перехода в ЗР и после возврата из него протекает
	;независимо, поэтому сохранение и восстановление SP не обязательно
	
	
	;Подготовка и загрузка в GDTR псевдодескриптора - 6-байтного поля данных, куда 
	;записывается информация о GDT: ее линейный базовый адрес (2-5) и размер (0-1)
	;GDT расположена в начале сегмента данных, базовый адрес которого хранится в ebp  
	mov dword ptr pdescr+2, ebp
	mov word ptr pdescr, gdt_size-1
	lgdt pdescr ; специальная привилеrированная команда, заrрузка таблицы GDT
	
	;ВОПРОС подготовка к возврату
	
	;вывод сообщения из РР на экран
	mov ah, 09h
	mov dx, offset msg_real_mode1
	int 21h
	
	
	;Запрет аппаратных прерываний (так как нет IDT)
	cli
	;Запрет немаскируемых прерываний, которые поступают в процессор по отдельной
	;линии (вход NMI микропроцессора) и не управляются битом IF. Специальной
	;команды нет, запрет установкой старшего бита (80h) в адресном порте 70h КМОП микросхемы.
	;Также осуществляется выборка байта для записи (состояния отключения, 0Fh). 
	;mov al, 80h
	mov al, 8Fh
	out 70h, al

	;Перевод процессора в ЗР установкой нулевого бита (pe) слова состояния машины
	mov eax, cr0
	or eax, 1
	mov cr0, eax
	
	;Теперь процессор работает в ЗР
	;после перехода в ЗР в теневых регистрах находятся правильные линейные базовые
	;адреса, и программа в целом будет выполняться правильно (см РФ, 306)
	
	;Загрузка в CS:IP селектор:смещение точки continue и очищение очереди команд
	;искусственно сконструированной командой дальнего перехода, которая
	;приводит к смене содержимого и IP, и CS, и очищает очередь предвыборки
	db 0EAh            ;Код команды far jmp 
	dw offset continue ;смещение continue
	dw 16              ;селектор сегмента команд

continue:
	;Загрузка в используемые сегментные регистры селекторов соответсвующих сегментов
	
	;Данные
	mov ax, 8
	mov ds, ax
	
	;Стек
	mov ax, 24
	mov ss, ax
	
	;Видеобуфер (ES)
 	mov ax, 32
 	mov es, ax
	
	
	;вывод сообщения из ЗР 
    mov cx, 26                   ;число выводимых символов
	mov ah, attr                 ;аттрибут выводимых символов (ah не меняется)
 	mov si, offset msg_prot_mode ;начало сообщения (si смещается)
	mov di, 3750                 ;начальное смещение на экране (di смещается)
screen_prot_mode:
	;LODSB копирует 1 байт из памяти по адресу DS:SI в регистр AL и изменяет SI
	lodsb
	;STOSW сохраняет регистр AX в ячейке памяти по адресу ES:DI и изменяет DI
 	stosw
    loop screen_prot_mode


	;Перевод процессора в РР сбросом нулевого бита слова состояния машины
	mov eax, CR0
	and eax, 0FFFFFFFEh
	mov CR0, eax
	
	;теперь процессор снова работает в РР
	;Загрузка в CS:IP сегмент:смещение точки return и очищение очереди команд
	;искусственно сконструированной командой дальнего перехода
	db 0EAh            ;Код команды far jmp 
	dw offset return   ;смещение return
	dw text            ;базовый адрес сегмента команд


return:

	;Восстановление адресуемости
	;сегмент данных
	mov AX, data
	mov DS, AX
	
	;сегмент стека
	mov AX, stk
	mov SS, AX

	;разрешение аппаратных и немаскируемых прерывний
	sti
	mov AL, 0
	out 70h, AL

	;вывод сообщения о возврате в РР на экран
	mov ah, 09h
	mov dx, offset msg_real_mode2
	int 21h
	
	;завершение программы (4сh) с кодом 0
	mov ax, 4C00h
	int 21h	
main endp	

;размер сегмента команд
code_size=$-main	

text ends

;сегмент стека
stk segment stack 'stack'
	db 256 dup('^')
stk ends

	end main
