.text
.global  thermo_update
thermo_update:
	pushl	%ebp
	movl	%esp, %ebp
	subl	$24, %esp

	movl	$0, -20(%ebp)						# temp @ %ebp-20

	movl	$0, -24(%ebp)						# display @ %ebp-24

	subl	$12, %esp
	leal	-20(%ebp), %eax						# &temp
	pushl	%eax
	call	set_temp_from_ports					# set_temp_from_ports(&temp)
	addl	$16, %esp
	movl	%eax, -12(%ebp)						# resultTempultPort @ %ebp-12

	subl	$8, %esp
	leal	-24(%ebp), %eax						# &display
	pushl	%eax
	pushl	-20(%ebp)						# temp
	call	set_display_from_temp	 	  			# set_display_from_temp(temp, &display)
	addl	$16, %esp
	movl	%eax, -16(%ebp)						# resultTemp @ %ebp-16

	cmpl	$1, -12(%ebp)						# if(resultTempultPort == 1
	je	.update_error
	cmpl	$1, -16(%ebp)						# || resultTemp == 1)
	jne	.update_done					  	# else
.update_error:
	movl	$1, %eax						# return 1
	jmp	.update_return

.update_done:
	movl	-24(%ebp), %eax						# display
	movl	%eax, THERMO_DISPLAY_PORT # THERMO_DISPLAY_PORT = display
	movl	$0, %eax						# return 0

.update_return:
	leave
	ret

.text
.global  set_temp_from_ports
set_temp_from_ports:
	pushl	%ebp
	movl	%esp, %ebp
	pushl	%esi
	subl	$32, %esp

	movl	THERMO_SENSOR_PORT, %eax
	cmpl	$64000, %eax						  # if(THERMO_SENSOR_PORT > 64000)
	jle	.not_overflow						  # else

	movl	$1, %eax						  # return 1
	jmp	.set_temp_return

.data

	my_int:                         				# declare location an single int
	        .int 1234               				# value 1234

	my_array:                       				# declare multiple ints in a row
	        .int 10                 				# for an array. Each are spaced
	        .int 20                 				# 4 bytes from each other
	        .int 30

.not_overflow:
	movb	THERMO_STATUS_PORT, %cl
	movl	8(%ebp), %edx						# temp
	movb	%cl, 2(%edx)						# temp->is_fahrenheit (temp+2) = THERMO_STATUS_PORT

	movl	THERMO_SENSOR_PORT, %eax
	movl	$0, %edx
	movl	$64, %esi
	idivl	%esi							# Remainder in %edx
	movl	%edx, -16(%ebp)						# num @ %ebp-16

	cmpl	$0, -16(%ebp)					  	# if(num == 0)
	jne	.num_nz							# else

	movl	THERMO_SENSOR_PORT, %eax
	movl	$0, %edx
	movl	$64, %esi
	idivl	%esi							# Quotient in %eax
	movl	8(%ebp), %edx						# temp
	subw	$500, %ax
	movw	%ax, (%edx)						# temp->tenth_degrees = (THERMO_SENSOR_PORT / 64) - 500

	jmp	.check_fahrenheit

.num_nz:
	cmpl	$31, -16(%ebp)					 	# if(num < 31)
	jge	.num_ge_31						# else

	movl	THERMO_SENSOR_PORT, %eax
	subl	-16(%ebp), %eax						# THERMO_SENSOR_PORT - num
	movl	$0, %edx
	movl	$64, %esi
	idivl	%esi							# Quotient in %eax
	movl	8(%ebp), %edx						# temp
	subw	$500, %ax
	movw	%ax, (%edx)						# temp->tenth_degrees

	jmp	.check_fahrenheit

.num_ge_31:
	movl	THERMO_SENSOR_PORT, %eax
	addl	-16(%ebp), %eax			  			# THERMO_SENSOR_PORT - num
	movl	$0, %edx
	movl	$64, %esi
	idivl	%esi							# Quotient in %eax
	movl	8(%ebp), %edx						# temp
	subw	$500, %ax
	movw	%ax, (%edx)						# temp->tenth_degrees

.check_fahrenheit:
	movl	8(%ebp), %eax						# temp
	movsbl	2(%eax), %eax						# temp+2 (temp->is_fahrenheit)
	cmpl	$1, %eax						# if(temp->is_fahrenheit == 1)
	jne	.set_temp_done					  	# else

	movl	8(%ebp), %eax
	movswl	(%eax), %eax						# %eax <- temp->tenth_degrees
	imull	$90, %eax						# %eax *= 90
	movl	$50, %ecx
	idivl	%ecx							# %eax /= 50
	addl	$320, %eax						# %eax += 320
	movw	%ax, %si
	movl	8(%ebp), %eax						# temp
	movw	%si, (%eax)						# temp->tenth_degrees = %eax

.set_temp_done:
	movl	$0, %eax						# return 0

.set_temp_return:
	addl	$32, %esp
	popl	%esi
	popl	%ebp
	ret

.text
.global  set_display_from_temp
set_display_from_temp:
	pushl	%ebp
	movl	%esp, %ebp
	pushl	%edi
	pushl	%esi
	subl	$84, %esp

	movsbl	10(%ebp), %eax						# %eax <- temp.is_fahrenheit (temp + 2)
	cmpl	$1, %eax						# if(temp.is_fahrenheit > 1)
	jle	.is_fahrenheit_ok					# else

	movl	$1, %eax						# return 1
	jmp	.set_disp_return

.is_fahrenheit_ok:
	movsbl	10(%ebp), %eax
	cmpl	$1, %ecx						# if fahrenheit
	jne	.check_celsius_oob   	 				# else

	movswl	8(%ebp), %eax			 			# %eax <- temp.tenth_degrees
	cmpl	$1220, %eax					 	# if(temp.tenth_degrees > 1220)
	jg	.f_is_oob						# It's out of bounds
	cmpl	$-580, %eax					 	# if(temp.tenth_degrees >= -580)
	jge	.temp_ok						# It's not out of bounds

.f_is_oob:
	movl	$1, %eax
	jmp	.set_disp_return

.check_celsius_oob:
	movswl	8(%ebp), %eax						# %eax <- temp.tenth_degrees
	cmpl	$500, %eax						# if(temp.tenth_degrees > 500)
	jg	.c_is_oob						# It's out of bounds
	cmpl	$-500, %eax						# if(temp.tenth_degrees >= -500)
	jge	.temp_ok						# It's not out of bounds

.c_is_oob:
	movl	$1, %eax
	jmp	.set_disp_return

.temp_ok:
	movl	$0x40, -80(%ebp)	  				# minusSign @ %ebp-80

	movl	$0x3F, -76(%ebp)	 				# arr[0] @ %ebp-76
	movl	$0x06, -72(%ebp)  					# arr[1]
	movl	$0x5B, -68(%ebp)  					# arr[2]
	movl	$0x4F, -64(%ebp)	  				# arr[3]
	movl	$0x66, -60(%ebp)					# arr[4]
	movl	$0x6D, -56(%ebp)					# arr[5]
	movl	$0x7D, -52(%ebp)					# arr[6]
	movl	$0x07, -48(%ebp)					# arr[7]
	movl	$0x7F, -44(%ebp)					# arr[8]
	movl	$0x6F, -40(%ebp)					# arr[9] @ %ebp-40

	movl	$0, -36(%ebp)						# displayVal @ %ebp-36

	movswl	8(%ebp), %eax						# %eax <- temp.tenth_degrees
	movl	%eax, -32(%ebp)						# num @ %ebp-32 = temp.tenth_degrees

	movl	$0x10000000, -28(%ebp)					# celsiusMask @ %ebp-28 = (0x1 << 28) = 0x10000000
	movl	$0x20000000, -24(%ebp)					# fahrenheitMask @ %ebp-24 = (0x1 << 29) = 0x20000000

	cmpl	$0, -32(%ebp)				 		# if(num < 0)
	jge	.calc_digits			   			# else

	movl	-80(%ebp), %eax			 			# minusSign
	movl	-36(%ebp), %ecx			 			# displayVal
	orl	%eax, %ecx						# %ecx |= %eax
	shll	$7, %ecx						# %ecx <<= 7
	movl	%ecx, -36(%ebp)			 			# displayVal = %ecx
	imull	$-1, -32(%ebp), %eax 					# %eax <- num * -1
	movl	%eax, -32(%ebp)			 			# num = %eax

.calc_digits:
	movl	-32(%ebp), %eax			 			# num
	movl	$0, %edx
	movl	$1000, %ecx
	idivl	%ecx							# %eax <- %edx:%eax / %ecx (num/1000)
	movl	$10, %ecx
	movl	$0, %edx
	idivl	%ecx							# %edx <- %edx:%eax % %ecx ((num/1000)%10)
	movl	%edx, -20(%ebp)		  				# temp_thousands @ %ebp-20 = (num / 1000) % 10

	movl	-32(%ebp), %eax	  					# num
	movl	$0, %edx
	movl	$100, %ecx
	idivl	%ecx							# %eax <- %edx:%eax / %ecx (num/100)
	movl	$10, %ecx
	movl	$0, %edx
	idivl	%ecx							# %edx <- %edx:%eax % %ecx ((num/100)%10)
	movl	%edx, -16(%ebp)		  				# temp_hundreds @ %ebp-16 = (num / 100) % 10

	movl	-32(%ebp), %eax		  				# num
	movl	$0, %edx
	movl	$10, %ecx
	idivl	%ecx							# %eax <- %edx:%eax / %ecx (num/10)
	movl	$10, %ecx
	movl	$0, %edx
	idivl	%ecx							# %edx <- %edx:%eax % %ecx ((num/10)%10)
	movl	%edx, -12(%ebp)		  				# temp_tens @ %ebp-12 = (num / 10) % 10

	movl	-32(%ebp), %eax						# num
	movl	$0, %edx
	movl	$1000, %ecx
	idivl	%ecx							# %edx <- %edx:%eax % %ecx (num%10)
	movl	%edx, -8(%ebp)		  				# temp_ones @ %ebp-8 = (num / 1000) % 10

	cmpl	$0, -20(%ebp)						# if(temp_thousands != 0)
	je	.no_thousands						# else

	movl	-20(%ebp), %eax						# %eax <- temp_thousands
	movl	-76(%ebp,%eax,4), %eax					# %eax <- arr[temp_thousands]
	movl	-36(%ebp), %ecx						# %ecx <- displayVal
	orl	%eax, %ecx						# %ecx |= arr[temp_thousands]
	shll	$7, %ecx						# %ecx <<= 7
	movl	%ecx, -36(%ebp)						# displayVal = %ecx

.no_thousands:
	cmpl	$0, -20(%ebp)
	jne	.hundreds_or_thousands
	cmpl	$0, -16(%ebp)
	je	.no_hundreds

.hundreds_or_thousands:
	movl	-16(%ebp), %eax						# %eax <- temp_hundreds
	movl	-76(%ebp,%eax,4), %eax					# %eax <- arr[temp_hundreds]
	movl	-36(%ebp), %ecx						# %ecx <- displayVal
	orl	%eax, %ecx						# %ecx |= arr[temp_hundreds]
	shll	$7, %ecx						# %ecx <<= 7
	movl	%ecx, -36(%ebp)						# displayVal = %ecx

.no_hundreds:
	movl	-12(%ebp), %eax						# %eax <- temp_tens
	movl	-76(%ebp,%eax,4), %eax					# %eax <- arr[temp_tens]
	movl	-36(%ebp), %ecx						# %ecx <- displayVal
	orl	%eax, %ecx						# %ecx |= arr[temp_tens]
	shll	$7, %ecx						# %ecx <<= 7

	movl	-8(%ebp), %eax						# %eax <- temp_ones
	movl	-76(%ebp,%eax,4), %eax	  				# %eax <- arr[temp_ones]
	orl	%eax, %ecx						# %ecx |= arr[temp_ones]
	movl	%ecx, -36(%ebp)						# displayVal = %ecx

	movsbl	10(%ebp), %ecx						# %ecx <- temp.is_fahrenheit
	cmpl	$1, %ecx						# if(temp.is_fahrenheit == 1)
	jne	.is_celsius						# else

	movl	-24(%ebp), %eax						# %eax <- fahrenheitMask
	movl	-36(%ebp), %ecx						# %ecx <- displayVal
	orl	%eax, %ecx						# %ecx |= fahrenheitMask
	movl	%ecx, -36(%ebp)						# displayVal = %ecx
	jmp	.set_disp

.is_celsius:
	movl	-28(%ebp), %eax						# %eax <- celsiusMask
	movl	-36(%ebp), %ecx						# %ecx <- displayVal
	orl	%eax, %ecx						# %ecx |= celsiusMask
	movl	%ecx, -36(%ebp)						# displayVal = %ecx

.set_disp:
	movl	-36(%ebp), %eax						# displayVal
	movl	12(%ebp), %ecx						# display
	movl	%eax, (%ecx)						# *display = displayVal

	movl	$0, %eax						# return 0

.set_disp_return:
	addl	$84, %esp
	popl	%esi
	popl	%edi
	popl	%ebp
	ret
 
