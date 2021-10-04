.386p

descr struc
    limit   dw 0
    base_l  dw 0
    base_m  db 0
    attr_1  db 0
    attr_2  db 0
    base_h  db 0
descr ends


idescr struc
    offs_l  dw 0
    sel     dw 0
    rsrv    db 0
    attr    db 0
    offs_h  dw 0
idescr ends


stack32 segment  para stack 'STACK'
    stack_start db  100h dup(?)
    stack_size = $-stack_start
stack32 ends


data32 segment para 'data'
	;дескриптор сегмента: <limit, base_l, base_m, attr_1, attr_2, base_h>	
	
	;attr_1=98h=10011000b: подчиненный сегмент кода, разрешено только исполнение, является сегментом памяти
	;					   0 уровень привелегий, присутсвует в памяти,

	;attr_1=92h=10010010b: сегмент данных (стека), разрешены чтение и запись, является сегментом памяти
	;					   0 уровень привелегий, присутсвует в памяти,	
	
	;нулевой дескриптор
    gdt_null  descr <>
	
	;16-разрядный (D=0) сегмент кода, граница в байтах (G=0)
    gdt_code16 descr <code16_size-1,0,0,98h,0,0>
	
	;32-разрядный (D=1) сегмент данных, граница в блоках по 4 Кбайт (G=1), размер: 4 Гб
    gdt_data4gb descr <0FFFFh,0,0,92h,0CFh,0>
	
	;32-разрядный (D=1) сегмент кода, граница в байтах (G=0)
    gdt_code32 descr <code32_size-1,0,0,98h,40h,0>
	
	;32-разрядный (D=1) сегмент данных, граница в байтах (G=0)
    gdt_data32 descr <data_size-1,0,0,92h,40h,0>
	
	;32-разрядный (D=1) сегмент стека, граница в байтах (G=0)
    gdt_stack32 descr <stack_size-1,0,0,92h,40h,0>
	
	;видеобуфер (размер страницы=4096 байт, базовый адрес=B8000h)
    gdt_video16 descr <4095,8000h,0Bh,92h,0,0>

    gdt_size=$-gdt_null	
    pdescr    df 0		
	
    code16s=8
    data4gbs=16
    code32s=24
    data32s=32
    stack32s=40
    video16s=48

    idt label byte
	
	;дескриптор (шлюз) прерывания: <offs_l, sel, rsrv, attr, offs_h>
	
	;attr=8Fh: тип-шлюз ловушки 386/486, системный объект, 0 уровень привелегий, P=1
    idescr_0_12 idescr 13 dup (<0,code32s,0,8Fh,0>)
	; исключение 13 - нарушение общей защиты 
    idescr_13 idescr <0,code32s,0,8Fh,0>
    idescr_14_31 idescr 18 dup (<0,code32s,0,8Fh,0>)
	
	;attr=8Eh: тип-шлюз прерывания 386/486, системный объект, 0 уровень привелегий, P=1
    int08 idescr <0,code32s,0,8Eh,0> 
    int09 idescr <0,code32s,0,8Eh,0>

    idt_size = $-idt  		
    ipdescr df 0	  		
    ipdescr16 dw 3FFh, 0, 0	

    mask_master db 0        
    mask_slave  db 0        

	asciimap db	0,1Bh,'1','2','3','4','5','6','7','8','9','0','-','=',8
							 db ' ','q','w','e','r','t','y','u','i','o','p','[',']','$'
							 db ' ','a','s','d','f','g','h','j','k','l',';','""',0
							 db '\','z','x','c','v','b','n','m',',','.','/',0,0,0,' ',0,0
							 db 0,0,0,0,0,0,0,0,0,0,0,0

    enter_pressed_f db 0	

    int09_pos dd 80*2*5
	
	int08_pos=80*2*3
	int08_symb db 'T'
	
	param db 34h  
	param_8 db 34h

    pm_msg_pos=0				
	pm_msg db 'Switched to protected mode. Press "Enter" to return...'
	
    mem_msg_pos=80*2			
	mem_msg db 'Memory: '
    mem_value_pos=80*2+7*2	
    mb_pos=80*2+11*2	
	
	rm_msg_1 db 'Start in real mode', 13, 10, '$'
	rm_msg_wait db 'Press any key to enter protected mode...', 13, 10, '$'
	rm_msg_2 db 'Back in real mode', 13, 10, '$'
	
	sub_caps db 0h

    data_size = $-gdt_null 
data32 ends


code32 segment para public 'code' use32
    assume cs:code32, ds:data32, ss:stack32

pm_start:
    mov ax, data32s
    mov ds, ax
    mov ax, video16s
    mov es, ax
    mov ax, stack32s
    mov ss, ax
    mov eax, stack_size
    mov esp, eax

    sti 
	
	mov ecx, 54                   
	mov ah, param                 
 	mov esi, offset pm_msg 
	xor edi, edi
	mov di, pm_msg_pos  
print_pm:
	lodsb
 	stosw
    loop print_pm
	
    mov ecx, 7                  
	mov ah, param              
 	mov esi, offset mem_msg 	
	xor edi, edi
	mov di, mem_msg_pos           
print_mem:
	lodsb
 	stosw
    loop print_mem

    call count_memory
	
	;ожидание ввода Enter
    proccess:
        test enter_pressed_f, 1
        jz  proccess

    cli

    db  0EAh
    dd  offset return_rm
    dw  code16s		


    new_int08 proc 
		push eax
		        
		mov edi, int08_pos 
		mov al, int08_symb 
        mov ah, param_8 
        ror ah, 1          
        mov param_8, ah
        stosw 

        mov al, 20h
        out 20h, al
		
		pop eax
        iretd 
    new_int08 endp
	
	
    new_int09 proc
		push eax 
		push ebx
		push es
		push ds

		in	al, 60h 			; чтение скан-кода нажатой клавиши из порта клавиатуры
		cmp	al, 1Ch 			; нажат Enter?
		je enter_pressed 	
		
	check_caps_on:
		cmp	al, 03Ah 			; нажат Caps (вкл)?
		jne check_caps_off
		mov bl, 32
		mov byte ptr sub_caps, bl
		
	check_caps_off:
		cmp	al, 0BAh 			; нажат Caps (выкл=вкл+80h)?
		jne translate_int09
		mov bl, 0
		mov byte ptr sub_caps, bl
	

	translate_int09:
		cmp al, 39h 			; скан-код обслуживаемой клавиши?
		ja exit_int09 	
		
		mov ebx, offset asciimap 
		xlatb 					; преобразовать в ASCII
		
		mov ebx, int09_pos 	
		cmp al, 8 				; нажат Backspace?
		je bs_pressed
		

		cmp al, 'a'
		jb print_int09
		cmp al, 'z'
		ja print_int09
		
		sub al, byte ptr sub_caps
		
	print_int09:
		mov es:[ebx], al 	
		add dword ptr int09_pos, 2 
		jmp short exit_int09
		
	bs_pressed: 			; нажат Backspace: нарисовать пробел в позиции предыдущего символа
		mov al, ' ' 			
		sub ebx, 2 		
		mov es:[ebx], al 
		mov int09_pos, ebx 	
		jmp short exit_int09
	
	enter_pressed:
		or enter_pressed_f, 1			
		
	exit_int09:
		; Разрешить работу клавиатуры
		in	al, 61h
		or	al, 80h
		out	61h, al
		
		mov	al, 20h
		out	20h, al

		pop ds
		pop es
		pop ebx
		pop	eax
		iretd
	new_int09 endp
	

    except_13 proc 
		add ESP, 4 		;коррекция стека на поле кода ошибки
        iret
    except_13 endp
	
    dummy_exc proc
        iret
    dummy_exc endp


    count_memory proc
		push fs
		push eax
		push ebx
		
        mov ax, data4gbs
        mov fs, ax

		;пропуск первого Мбайта
        mov ebx,  100001h

        mov dl,   0AEh
		;FFEF FFFE+10 0001=F0000 0000=4 Гб
        mov ecx, 0FFEFFFFEh

        iterate_through_memory:
            mov dh, fs:[ebx] 
            mov fs:[ebx], dl    
            cmp fs:[ebx], dl        
            jnz print_memory_counter   
			
            mov fs:[ebx], dh 
            inc ebx
        loop iterate_through_memory

    print_memory_counter:
		;перевод определенного объема памяти из байтов в мегабайты
        mov eax, ebx 
        xor edx, edx 
        mov ebx, 100000h
        div ebx

        mov ebx, mem_value_pos
        call print_mem_value


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


    print_mem_value proc
		push ecx
		push ebx
		push edx
		
		add ebx, 4
		mov ecx, 10
		
	print_time:
		xor edx, edx
		div ecx
		add edx, '0'
		mov dh, param
		mov es:[ebx], dx
		sub bx, 2
		cmp eax, 0
		jnz print_time
		
		pop edx 
		pop ebx
		pop ecx
		
        ret
    print_mem_value endp

    code32_size = $-pm_start
code32 ends


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
    mov ah, 10h
    int 16h

    ;очистка экрана
    mov ax, 3
    int 10h


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
	mov ebp, eax 	;сохранение линейного адреса GDT, расположенной в начале сегмента данных
    mov word ptr gdt_data32.base_l, ax  
    rol eax, 16                       
    mov byte ptr gdt_data32.base_m, al   

    mov ax, stack32
    shl eax, 4                        
    mov word ptr gdt_stack32.base_l, ax  
    rol eax, 16                       
    mov byte ptr gdt_stack32.base_m, al  


    mov dword ptr pdescr+2, ebp
    mov word ptr  pdescr, gdt_size-1  
    lgdt fword ptr pdescr     


    lea eax, es:dummy_exc
    mov idescr_0_12.offs_l, ax 
	mov idescr_14_31.offs_l, ax 
    shr eax, 16             
    mov idescr_0_12.offs_h, ax 
	mov idescr_14_31.offs_h, ax 

    lea eax, es:except_13
    mov idescr_13.offs_l, ax 
    shr eax, 16             
    mov idescr_13.offs_h, ax 

    lea eax, es:new_int08
    mov int08.offs_l, ax
    shr eax, 16
    mov int08.offs_h, ax

    lea eax, es:new_int09
    mov int09.offs_l, ax 
    shr eax, 16             
    mov int09.offs_h, ax 



    mov ax, data32
    shl eax, 4
    add eax, offset idt	
    mov  dword ptr ipdescr + 2, eax 
    mov  word ptr  ipdescr, idt_size-1 


    ;сохранение значений масок прерываний для восстановления при возвращении в реальный режим
    in  al, 21h                     
    mov mask_master, al             
    in  al, 0A1h                    
    mov mask_slave, al
	

    ;перепрограммирование ведущего контроллера
    mov al, 11h	
    out 20h, al                  
    mov al, 32
    out 21h, al                  
    mov al, 4
    out 21h, al
    mov al, 1
    out 21h, al

	;запрет всех прерваний кроме прерываний от таймера (0) и клавиатуры (1) в ведущем контроллере 
    mov al, 0FCh
    out 21h, al
    ;запрет всех прерваний в ведомом контроллере 
    mov al, 0FFh
    out 0A1h, al	

    lidt fword ptr ipdescr                                    

    ; открытие линии А20 
	in  al, 92h
    or  al, 2
    out 92h, al
	 
    cli

    mov eax, cr0
    or eax, 1     
    mov cr0, eax

    db  66h 
    db  0EAh			
    dd  offset pm_start 
    dw  code32s


return_rm:
    mov eax, cr0
    and al, 0FEh                
    mov cr0, eax

    db  0EAh    
    dw  offset go
    dw  code16	

go:
    mov ax, data32   
    mov ds, ax
    mov ax, code32
    mov es, ax
    mov ax, stack32   
    mov ss, ax
    mov ax, stack_size
    mov sp, ax

	;перепрограммирование ведущего контроллера
    mov al, 11h
    out 20h, al
    mov al, 8	
    out 21h, al
    mov al, 4  
    out 21h, al
    mov al, 1  
    out 21h, al

	;восстанавление масок 
    mov al, mask_master
    out 21h, al
    mov al, mask_slave
    out 0A1h, al

    lidt    fword ptr ipdescr16

    ;закрытие линии A20
    in  al, 70h 
    and al, 7Fh
    out 70h, al
	
	sti

    mov ax, 3
    int 10h

    mov ah, 09h
    lea dx, rm_msg_2
    int 21h

    mov ax, 4C00h
    int 21h

    code16_size = $-start  
code16 ends

end start