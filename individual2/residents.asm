.286
code segment
	assume cs:code, ss:code, ds:code, es:code

	org 0		;переходим на начало программы
	begin equ $	;begin - константа содержащее адрес начала программы(смещение)
	org 100h	;перепрыгиваем PSP


	main: jmp start 
		old_int dd ?		;старый обработчик прерываний
		flag	dw 4242h	;флаг, признак того что резидент загружен

	;собственно код, который будет резидентным
	new_int proc far
		pushf
		pusha

		push cs	;загрузка ds
		pop ds	;

		;данные------------
		jmp _skip_data
			time db 8 dup('$')
		_skip_data:
		;-------------------

		in al, 60h	;читаем клавиатуру

		cmp al, 1	;проверяем нажат ли insert
		je _pressed
		jmp _not_pressed
		_pressed:
			;если нажат, то
			;показываем время
			_show_time:
				;очистить экран
				mov ax, 0600h
				mov bh, 07
				mov cx, 0000
				mov dx, 184fh
				int 10h
	
				;установка курсора в середину
				mov ah, 02
				mov bh, 00
				mov dl, 80/2 - 3
				mov dh, 12
				int 10h
	
				
				;получение текущего времени
				mov ah, 2ch
				int 21h		;ch - часы, cl - минуты
				
				;создание строки содержащего время
				sub ah, ah			;второй символ часа
				mov al, ch
				mov bl, 10
				div bl
				add ah, '0'
				mov byte ptr time+1, ah
	
				sub ah, ah			;первый символ часа
				div bl
				add ah, '0'
				mov byte ptr time, ah
	
				mov byte ptr time+2, ':'	;разделитель

				sub ah, ah			;второй символ минуты
				mov al, cl
				div bl
				add ah, '0'
				mov byte ptr time+4, ah
	
				sub ah, ah
				div bl
				add ah, '0'
				mov byte ptr time+3, ah
	
				;вывод строки time
				lea dx, time
				mov ah, 09h
				int 21h

				
				;задрежка
				mov cx, 20000
				delay:
					nop
				loop delay
				
				in al, 60h
				cmp al, 1ch
				je _brk
			jmp _show_time	
			_brk:

			;разблокируем клавиатуру
			in al, 61h
			or al, 10000000b
			out 61h, al
			and al, 01111111b
			out 61h, al
			mov al, 20h
			out 20h, al
			;----------------------

			;выходим
			popa
			popf
			iret
		_not_pressed:
			;если не зажат, то
			popa		;восстанавливаем регистры
			popf		;

			jmp cs:old_int	;и обрабатываем клавиатуру старым прерыванием	(просто переходим по адрессу старой функции)
	new_int endp

	code_len equ ($-begin)		;подсчитываем объем памяти занимаемый кодом
	
	start:
		mov ax, cs	;загрузка ds
		mov ds, ax

		;получение вектора прерывания;;;;;;;;;;;;;;;;;;;;;
		;in:	ah = 35h
		;	al = номер прерывания
		;out:	es:bx - адрес обработчика прерываний
		mov ah, 35h
		mov al, 09h	;09h - вывод строки
		int 21h		;теперь в bx находится адрес начала кода резидента, а в es - начало сегмента
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		
		cmp es:[bx-2], 4242h		;проверяем, находится ли значение флага в памяти(т.е резидент загружен)
		jne _load_resident		;если нет, то загружаем резидент
			;если, резидент уже загружен, то выгружаем его

			push ds		;сохраняем значение ds в стеке
			
			;устанавливаем вектор прерывания старым значением;;;;;;;;;;;;;
			;in:	ah = 25h
			;	al = номер прерывания
			;	ds:dx = вектор прерывания: адресс программы обработки прерывания
			mov ah, 25h
			mov al, 09h	;в таблице прерываний заменим прерывание с номером 09h старым значением

			mov dx, es:[bx-4] ;ds = старшая половина двойного слова old_int		(почему нельзя обратиться напрямую к old_int?)
			mov ds, dx

			mov dx, es:[bx-6] ;dx = младшая половина old_int
			int 21h
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

			pop ds		;восстанавливаем ds
			
			;выходим
			mov ax, 4c00h
			int 21h

		_load_resident:	
			;если резидент не зугружен, то загружаем его		

			;сохраняем старое значение вектора прерываний
			mov word ptr old_int, bx
			mov word ptr old_int+2, es

			;устанавливаем вектор прерывания новым значением;;;
			mov ah, 25h
			mov al, 09h
			;в ds уже находится адрес сегмента кода
			lea dx, new_int
			int 21h
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


			;выходим и оставляем программу в памяти
			;in:	ah = 31h
			;	al = код выхода
			;	dx = объем памяти (в параграфах) занимаемой программой, которая будет находится в памяти
			mov ah, 31h
			mov al, 0
			mov dx, (code_len/16) + 1	;1 параграф - 16 байт
			int 21h
			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
code ends
end main
