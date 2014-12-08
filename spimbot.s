# syscall constants 
PRINT_STRING_SYS = 4

# movement memory-mapped I/O
VELOCITY             = 0xffff0010
ANGLE                = 0xffff0014
ANGLE_CONTROL        = 0xffff0018

# coordinates memory-mapped I/O
BOT_X                = 0xffff0020
BOT_Y                = 0xffff0024

# planet memory-mapped I/O
LANDING_REQUEST      = 0xffff0050
TAKEOFF_REQUEST      = 0xffff0054
PLANETS_REQUEST      = 0xffff0058

# puzzle memory-mapped I/O
PUZZLE_REQUEST       = 0xffff005c
SOLVE_REQUEST        = 0xffff0064

# debugging memory-mapped I/O
PRINT_INT            = 0xffff0080

# interrupt constants
DELIVERY_MASK        = 0x800
DELIVERY_ACKNOWLEDGE = 0xffff0068

# Zuniverse constants
NUM_PLANETS = 5

# planet_info struct offsets
orbital_radius = 0
planet_radius = 4
planet_x = 8
planet_y = 12
favor = 16
enemy_favor = 20
planet_info_size = 24

# puzzle node struct offsets
str = 0
solution = 8
next = 12

.data

.align 2
planets: .space 120                  # array of planets in the Zuniverse
pending_requests: .word 0 0 0 0 0    # array indicating planets at which we have a pending puzzle request
delivered_puzzles: .word 0 0 0 0 0   # array indicating planets at which a puzzle has been delivered
puzzles: .space 40960                # 8192 * 5 --- array of puzzles

.text
puts:
	li	$v0, 4
	syscall
	li	$v0, 11
	li	$a0, '\n'
	syscall
	jr	$ra

# puzzle_solver ##################################################
# 
# argument $a0: array index of the planet to move to
# returns       nothing
puzzle_solver:
	sub	$sp, $sp, 20
	sw	$ra, 0($sp)		# save $ra and free up 4 $s registers for
	sw	$s0, 4($sp)		# str1
	sw	$s1, 8($sp)		# str2
	sw	$s2, 12($sp)		# length
	sw	$s3, 16($sp)		# i

	move	$s0, $a0		# str1
	move	$s1, $a1		# str2

	jal	my_strlen

	move 	$s2, $v0		# length
	li	$s3, 0			# i = 0
ps_loop:
	bgt	$s3, $s2, ps_return_minus_1
	move	$a0, $s0		# str1
	move	$a1, $s1		# str2
	jal	my_strcmp
	beq	$v0, $0, ps_return_i
	
	move	$a0, $s1		# str2
	jal	rotate_string_in_place_fast
	add	$s3, $s3, 1		# i ++
	j	ps_loop

ps_return_minus_1:
	li	$v0, -1
	j	ps_done

ps_return_i:
	move	$v0, $s3

ps_done:	
	lw	$ra, 0($sp)		# restore registers and return
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	add	$sp, $sp, 20
	jr	$ra

my_strcmp:
	li	$t3, 0			# i = 0
my_strcmp_loop:
	add	$t0, $a0, $t3		# &str1[i]
	lb	$t0, 0($t0)		# c1 = str1[i]
	add	$t1, $a1, $t3		# &str2[i]
	lb	$t1, 0($t1)		# c2 = str2[i]

	beq	$t0, $t1, my_strcmp_equal
	sub	$v0, $t0, $t1		# c1 - c2
	jr	$ra

my_strcmp_equal:
	bne	$t0, $0, my_strcmp_not_done
	li	$v0, 0
	jr	$ra

my_strcmp_not_done:
	add	$t3, $t3, 1		# i ++
	j	my_strcmp_loop

rotate_string_in_place_fast:
	sub	$sp, $sp, 8
	sw	$ra, 0($sp)
	sw	$a0, 4($sp)

	jal	my_strlen
	move	$t0, $v0		# length
	lw	$a0, 4($sp)
	lb	$t1, 0($a0)		# was_first = str[0]

	div	$t3, $t0, 4		# length_in_ints = length / 4;

	li	$t2, 0			# i = 0
	move	$a1, $a0		# making copy of 'str' for use in first loop
rsipf_loop1:
	bge	$t2, $t3, rsipf_loop2_prologue
	lw	$t4, 0($a1)		# unsigned first_word = str_as_array_of_ints[i]
	lw	$t5, 4($a1)		# unsigned second_word = str_as_array_of_ints[i+1]
	srl	$t6, $t4, 8		# (first_word >> 8)
	sll	$t7, $t5, 24		# (second_word << 24)
	or	$t7, $t7, $t6		# combined_word = (first_word >> 8) | (second_word << 24)
	sw	$t7, 0($a1)		# str_as_array_of_ints[i] = combined_word
	add	$t2, $t2, 1		# i ++
	add	$a1, $a1, 4		# str_as_array_of_inst ++
	j	rsipf_loop1		

rsipf_loop2_prologue:
	mul	$t2, $t3, 4
	add	$t2, $t2, 1		# i = length_in_ints*4 + 1
rsipf_loop2:
	bge	$t2, $t0, rsipf_done2
	add	$t3, $a0, $t2		# &str[i]
	lb	$t4, 0($t3)		# char c = str[i]
	sb	$t4, -1($t3)		# str[i - 1] = c
	add	$t2, $t2, 1		# i ++
	j	rsipf_loop2		
	
rsipf_done2:
	add	$t3, $a0, $t0		# &str[length]
	sb	$t1, -1($t3)		# str[length - 1] = was_first
	lw	$ra, 0($sp)
	add	$sp, $sp, 8
	jr	$ra

my_strlen:
	li	$v0, 0			# length = 0  (in $v0 'cause return val)
my_strlen_loop:
	add	$t1, $a0, $v0		# &str[length]
	lb	$t2, 0($t1)		# str[length]
	beq	$t2, $0, my_strlen_done
	
	add	$v0, $v0, 1		# length ++
	j 	my_strlen_loop

my_strlen_done:
	jr	$ra

# move_to_planet ##################################################
# 
# argument $a0: array index of the planet to move to
# returns       nothing

move_to_planet:
	sw $zero, TAKEOFF_REQUEST
	li $t0, 10
	sw $t0, VELOCITY

planet_info:
	la $t2, planets 
	sw $t2, PLANETS_REQUEST
	mul $t8, $a0, planet_info_size
	add $t3, $t8, $t2		# Start of planet i's structs in memory
move_x:
	lw $t4, planet_x($t3)			# Load planet i's x coordinate 
	lw $t5, BOT_X			# Load the x coordinates of SPIMBot
	beq $t5, $t4, move_y
	blt $t5, $t4, go_right
	bgt $t5, $t4, go_left
move_y:
	lw $t4, planet_y($t3)			# Load planet i's y coordinate
	lw $t5, BOT_Y			       # Load the y coordinates of SPIMBot
	beq $t5, $t4, landing
	blt $t5, $t4, go_up
	bgt $t5, $t4, go_down
	
go_right:
	li $t0, 0			
	sw $t0, ANGLE
	li $t0, 1
	sw $t0, ANGLE_CONTROL		# Absolute angle
	j move_x
go_left:
	li $t0, 180
	sw $t0, ANGLE
	li $t0, 1	
	sw $t0, ANGLE_CONTROL
	j move_x
go_up:
	li $t0, 90
	sw $t0, ANGLE
	li $t0, 1
	sw $t0, ANGLE_CONTROL
	j move_y
go_down:
	li $t0, 270
	sw $t0, ANGLE
	li $t0, 1
	sw $t0, ANGLE_CONTROL

	j move_y

landing:
	sw $zero, VELOCITY
check:
	la $t2, planets 
	sw $t2, PLANETS_REQUEST
	mul $t8, $a0, planet_info_size
	add $t3, $t8, $t2
	lw $t4, 8($t3)
	lw $t5, 12($t3)
	lw $t6, BOT_X
	lw $t7, BOT_Y
	bne $t6, $t4, check
	bne $t7, $t5, check
	sw $zero, LANDING_REQUEST
	li $t9, 7
	lw $t9, LANDING_REQUEST
	jr $ra

#  solve_puzzles ###################################################
#
# arguments: a0: index
# return: nothing
solve_puzzles: 

	sub $sp $sp, 12
	sw  $ra, 0($sp)
	sw  $s0, 4($sp)
	sw  $s1, 8($sp)

	la  $t0, puzzles    # &puzzles[0]
	mul $t1, $a0, 8192  # i * 8196
	add $s1, $t0, $t1   # &puzzles[i]->head
	lw  $s0, 0($s1)     # puzzles[i]->head

solve_loop:

	la	$a0, 0($s0) # str1
	la	$a1, 4($s0) # str2
	#jal puts
	jal	puzzle_solver							
	sw	$v0, solution($s0)
	la	$s0, next($s0)       # puzzles[i]->next
	bne	$s0, 0, solve_loop

	sw	$s1, SOLVE_REQUEST						#would t0 get preserved?

	lw  $ra, 0($sp)
	lw  $s0, 4($sp)
	lw  $s1, 8($sp)
	add $sp, $sp, 12
	jr  $ra

# main ############################################################
#
# arguments: none
# return: nothing
main: 

	# enable interrupts
	li	$t4, DELIVERY_MASK		   # delivery interrupt enable bit
	or	$t4, $t4, 1		           # global interrupt enable
	mtc0	 $t4, $12		       # set interrupt mask (Status register)

	# all free

	# free up some registers
	sub $sp, $sp, 16
	sw  $s0, 0($sp)
	sw  $s1, 4($sp)
	sw  $s2, 8($sp)
	sw  $s3, 12($sp)

	# all free
	
	# TODO: request puzzles from starting planet
	#lw $t0, LANDING_REQUEST($0) # t0 index of current planet 

main_loop:

	li  $s0, 0         # i
	li  $s1, -1        # j

main_delv_check:                           # chcek if any puzzles have been delivered

	bge $s0, 5, main_delv_success_check

	la  $t0, delivered_puzzles       # &delivered_puzzles[0]
	mul $t1, $s0, 4                  # i * 4
	add $t0, $t1, $t0                # &delivered_puzzles[i]
	lw  $t0, 0($t0)                  # delivered_puzzles[i]
	beq $t0, 0, main_delv_check_inc  # !delivered_puzzles[i] #Changed this part to 1 from 0 and made it go to success check.
	move $s1, $s0        # j = i
	j    main_delv_success_check

main_delv_check_inc:

	add $s0, $s0, 1 # i++
	j   main_delv_check

main_delv_success_check:          

	blt $s1, 0, main_find_planet
	move $a0, $s1
	jal  move_to_planet                  # move to the planet 
	move $a0, $s1
	jal solve_puzzles                    # solve delivered puzzles

main_find_planet:

	li  $s0, 0 # i = 0

main_find_planet_loop:

	bge $s0, 5, main_loop

	la  $t0, pending_requests              # &pending_requests[0]
	mul $t1, $s0, 4                        # i * 4
	add $t0, $t1, $t0                      # &pending_requests[i]
	lw  $t1, 0($t0)                        # pending_requests[i]
	bne $t1, 0, main_find_planet_loop_inc  # pending_requests[i] != 0

	move $a0, $s0                          
	jal  move_to_planet

	la  $t2, puzzles
	mul $t3, $s0, 8192
	add $t2, $t3, $t2                      # &puzzles[i]
	sw  $t2, PUZZLE_REQUEST
	
	la  $t0, pending_requests              # &pending_requests[0]
	mul $t1, $s0, 4                        # i * 4
	add $t0, $t1, $t0   
	li  $t2, 1
	sw  $t2, 0($t0)
	j   main_loop

main_find_planet_loop_inc:

	add $s0, $s0, 1 # i++
	j main_find_planet_loop

# interrupt handler ###############################################
.kdata				           # interrupt handler data (separated just for readability)
chunkIH:	.space 16	       # space for three registers 
	
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		    # Get some free registers                  
	sw  $v0, 4($k0)   
	sw  $t0, 8($k0)
	sw  $t1, 12($k0)

	mfc0	$k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:			# Interrupt:                             
	
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts     

	and $a0, $k0, DELIVERY_MASK # is there a delivery interrupt?
	bne $a0, 0, delivery_interrupt 

	li	$v0, PRINT_STRING_SYS	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done


delivery_interrupt:

	# logic for interrupt:
	#
	# int i;
	# for (i = 0; i < 5; i++) {
	# 	if (puzzles[i] != NULL && delivered_puzzles[i] == 0) {
	# 		delivered_puzzles[i] = 1;	
	# 		break;
	# 	}
	# }

	li  $v0, 0                          # i

	del_int_loop:
		
		bge $v0, 5, del_int_loop_done   # !(i < 5)
		
		la  $a0, puzzles                # a0 = &puzzles[0]
		mul $t0, $v0, 8192              # t0 = i * 8192 
		add $a0, $t0, $a0               # a0 = &puzzles[i]
		lw  $a0, 0($a0)                 # a0 = puzzles[i]
		beq $a0, 0, del_int_loop_inc    # puzzles[i] == NULL

		la  $a0, delivered_puzzles      # a0 = &delivered_puzzles[0]
		mul $t0, $v0, 4                 # t0 = i * 4
		add $a0, $t0, $a0               # a0 = &delivered_puzzles[i]
		lw  $a0, 0($a0)                 # a0 = delivered_puzzles[i]
		bne $a0, 0, del_int_loop_inc    # delivered_puzzles[i] != 0

		li  $t0, 1
		mul $t1, $v0, 4                 # i * 4
		la  $a0, delivered_puzzles      # &delivered_puzzles[0]
		add $t1, $a0, $t1               # &delivered_puzzles[i]
		sw  $t0, 0($a0)                 # delivered_puzzles[i] = 1
		j   del_int_loop_done           # break;

	del_int_loop_inc:
		
		add $v0, $v0, 1                 # i++
		j   del_int_loop

	del_int_loop_done:

		sw  $v0, DELIVERY_ACKNOWLEDGE
		j   interrupt_dispatch

non_intrpt:				    # was some non-interrupt

	li	$v0, PRINT_STRING_SYS
	la	$a0, non_intrpt_str
	syscall				    # print out an error message
	# fall through to done

done:

	la	$k0, chunkIH
	lw	$a0, 0($k0)		    # Restore saved registers
	lw  $v0, 4($k0)
	lw  $t0, 8($k0)
	lw  $t1, 12($k0)

.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret
