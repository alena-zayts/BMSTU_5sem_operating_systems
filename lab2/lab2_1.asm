.386P

;Структура descr для описания дескрипторов сегментов 
descr struc
limit dw 0
base_l dw 0
base_m db 0
attr_1 db 0
attr_2 db 0
base_h db 0
descr ends


;СЕГМЕНТ ДАННЫХ
data segment use16

;Описание GDT

;<limit, base_l, base_m, attr_1, attr_2, base_h>
;Базы сегментов будут вычислены программно и занесены в соответсвующие
;дескрипторы на этапе выполнения. Фактические значения размеров сегментов 
;будут вычислены транслятором.

;attr_2=0: 7 бит G=0: граница задается в байтах, 6 бит D=0: 16-разрядные операнды и адреса

;attr_1=98h=10011000b: 7 бит P=1: сегмент представлен в памяти, 6-5 биты DPL=0: уровень 
;приоритета ядра системы, 4 бит S=1: обычный сегмент (памяти), 3-1 биты тип сегмента: 
;3 бит=1-сегмент кода, 2 бит=0-код подчинен, 1 бит=0-чтение из сегмента запрещено, 
;0 бит A устанавливается процессором

;attr_1=92h=10010010b: 7 бит P=1: сегмент представлен в памяти, 6-5 биты DPL=0: уровень 
;приоритета ядра системы, 4 бит S=1: обычный сегмент (памяти), 3-1 биты тип сегмента: 
;3 бит=0-сегмент данных/стека, 2 бит=0-сегмент данных, 1 бит=0-модификации запрещены, 
;0 бит A устанавливается процессором

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

gdt_size=$-gdt_null

pdescr dq 0	;псевдодескриптор для команды lgdt
attr db 34h  
msg_real_mode1 db 'start in real mode', 13, 10, '$'
msg_real_mode2 db 'end in real mode', 13, 10, '$'
msg_prot_mode db 'switched to protected mode'

data_size=$-gdt_null  
data ends


;СЕГМЕНТ КОМАНД
text segment 'code' use16
	assume CS:text, DS:data
main proc
	;Инициализация сегментных регистров, 
	;Завершение формирования дескрипторов сегментов программы заполнением 
	;базовых адресов сегментов. 
	
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
	
	
	;Подготовка и загрузка в GDTR псевдодескриптора 
	mov dword ptr pdescr+2, ebp
	mov word ptr pdescr, gdt_size-1
	lgdt pdescr
	
	
	mov ah, 09h
	mov dx, offset msg_real_mode1
	int 21h
	
	;Запрет аппаратных и немаскируемых прерываний 
	cli
	mov al, 80h
	out 70h, al

	;Перевод процессора в ЗР установкой нулевого бита (PE) слова состояния машины
	mov eax, cr0
	or eax, 1
	mov cr0, eax
	
	
	;Загрузка в CS:IP селектор:смещение точки continue и очищение очереди команд
	;искусственно сконструированной командой дальнего перехода
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
	
	
    mov cx, 26    
	mov ah, attr  
 	mov si, offset msg_prot_mode
	mov di, 3750
screen_prot_mode:
	;LODSB копирует 1 байт из памяти по адресу DS:SI в регистр AL и изменяет SI
	lodsb
	;STOSW сохраняет регистр AX в ячейке памяти по адресу ES:DI и изменяет DI
 	stosw
    loop screen_prot_mode
	
	
	;Подготовка перевода в РР: необходимо перезаписать содержимое теневых регистров
	;занесение в поля границ всех дескрипторов FFFFh
	;mov gdt_data.limit, 0FFFFh
	;mov gdt_code.limit, 0FFFFh
	;mov gdt_stack.limit,0FFFFh
	;mov gdt_screen.limit,0FFFFh
	
	;mov ax, 8
	;mov ds, ax
	;mov ax, 24
	;mov ss, ax
	;mov ax, 32
	;mov es, ax
	
	;Сегментный регистр CS программно недоступен, поэтому его загрузку придется выполнить с 
	;помощью искусственно сформированной команды дальнего перехода 
	db 0EAh		 
	dw offset go 
	dw 16       

go:
	;Перевод процессора в РР сбросом нулевого бита слова состояния машины
	mov eax, CR0
	and eax, 0FFFFFFFEh
	mov CR0, eax
	
	;Загрузка в CS:IP сегмент:смещение точки return и очищение очереди команд
	db 0EAh            
	dw offset return   
	dw text           

return:
	;Восстановление операционной среды РР 
	mov AX, data
	mov DS, AX
	mov AX, stk
	mov SS, AX

	;разрешение аппаратных и немаскируемых прерывний
	sti
	mov AL, 0
	out 70h, AL

	mov ah, 09h
	mov dx, offset msg_real_mode2
	int 21h
	
	mov ax, 4C00h
	int 21h	
main endp	

code_size=$-main	

text ends

;СЕГМЕНТ СТЕКА
stk segment stack 'stack'
	db 256 dup('^')
stk ends

	end main