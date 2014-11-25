.data
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

.align 2
puzzles_received: .space 4

.align 2
puzzles: .space 8192

.align 2
planets: .space 120

.text 

# main ############################################################
#
# arguments: none
# return: nothing
main:

	sub $sp, $sp, 24
	sw  $ra, 0($sp)
	sw  $s0, 4($sp)
	sw  $s1, 8($sp)
	sw  $s2, 12($sp)
	sw  $s3, 16($sp)
	sw  $s4, 20($sp)
	
	# enable interrupts
	li	$t4, DELIVERY_MASK		   # delivery interrupt enable bit
	or	$t4, $t4, 1		           # global interrupt enable
	mtc0	 $t4, $12		       # set interrupt mask (Status register)

	la $s0, puzzles_received       # s0 = &puzzles received flag
	sw $0, 0($s0)                  # init received to 0

	la $s1, puzzles                # s1 = &puzzles

	li $s2, 0                      # s2 = favor

	lw $s4, LANDING_REQUEST        # s4 = curr_planet

request_puzzle:

	sw $s1, PUZZLE_REQUEST         # request puzzles

wait_for_puzzles: 

	lw  $t0, 0($s0)
	beq $t0, 1, solve_puzzles 
	j wait_for_puzzles

solve_puzzles:

	sw  $0, 0($s0)                 # reset flag
	move $s3, $s1

solve_puzzles_loop:

	beq  $s3, $0, submit_solutions # end of the list

	lw   $a0, 0($s3)
	lw   $a1, 4($s3)
	jal  puzzle_solve              # get the solution

	sw   $v0, solution($s3)        # store the solution
	lw   $s3, next($s3)

	j solve_puzzles_loop

submit_solutions:

	sw   $s1, SOLVE_REQUEST        # submit the solutions
	
	la   $s5, planets
	sw   $s5, PLANETS_REQUEST      # s5 = &planets[0]
	mul  $t0, $s4, 24
	add  $s5, $t0, $s5             # s5 = &planets[curr_planet]
	lw   $s2, favor($s5)           # s2 = curr_favor

	bge  $s2, 10, main_done
	j request_puzzle

main_done:

	lw  $ra, 0($sp)
	lw  $s0, 4($sp)
	lw  $s1, 8($sp)
	lw  $s2, 12($sp)
	lw  $s3, 16($sp)
	lw  $s4, 20($sp)
	add $sp, $sp, 24

	jr  $ra

# my strlen  ########################################################
#
# argument $a0: string whose length we want to know
# return: length of string
my_strlen:

	li	$v0, 0			# length = 0  (in $v0 'cause return val)

my_strlen_loop:

	add	$t1, $a0, $v0	# &str[length]
	lb	$t2, 0($t1)		# str[length]
	beq	$t2, $0, my_strlen_done
	
	add	$v0, $v0, 1		# length ++
	j 	my_strlen_loop

my_strlen_done:

	jr	$ra

# rotate string in place ###############################################
#
# argument $a0: string to rotate
# return: rotated string
rotate_string_in_place:

	sub	$sp, $sp, 8
	sw	$ra, 0($sp)
	sw	$a0, 4($sp)

	jal	my_strlen
	move	$t0, $v0	# length
	lw	$a0, 4($sp)
	lb	$t1, 0($a0)	    # was_first = str[0]

	div	$t3, $t0, 4	    # length_in_ints = length / 4;

	li	$t2, 0		    # i = 0
	move	$a1, $a0	# making copy of 'str' for use in first loop

rsipf_loop1:

	bge	$t2, $t3, rsipf_loop2_prologue
	lw	$t4, 0($a1)	    # unsigned first_word = str_as_array_of_ints[i]
	lw	$t5, 4($a1)	    # unsigned second_word = str_as_array_of_ints[i+1]
	srl	$t6, $t4, 8	    # (first_word >> 8)
	sll	$t7, $t5, 24	# (second_word << 24)
	or	$t7, $t7, $t6	# combined_word = (first_word >> 8) | (second_word << 24)
	sw	$t7, 0($a1)	    # str_as_array_of_ints[i] = combined_word
	add	$t2, $t2, 1	    # i ++
	add	$a1, $a1, 4	    # str_as_array_of_inst ++
	j	rsipf_loop1		

rsipf_loop2_prologue:

	mul	$t2, $t3, 4
	add	$t2, $t2, 1	    # i = length_in_ints*4 + 1

rsipf_loop2:

	bge	$t2, $t0, rsipf_done2
	add	$t3, $a0, $t2	# &str[i]
	lb	$t4, 0($t3)	    # char c = str[i]
	sb	$t4, -1($t3)	# str[i - 1] = c
	add	$t2, $t2, 1   	# i ++
	j	rsipf_loop2		
	
rsipf_done2:

	add	$t3, $a0, $t0	# &str[length]
	sb	$t1, -1($t3)	# str[length - 1] = was_first
	lw	$ra, 0($sp)
	add	$sp, $sp, 8
	jr	$ra

# string compare ######################################################
#
# argument $a0: string 1
# argument $a1: string 2
# return: difference between str 1 and str 2
my_strcmp:

	li	$t3, 0		# i = 0

my_strcmp_loop:

	add	$t0, $a0, $t3	# &str1[i]
	lb	$t0, 0($t0)	# c1 = str1[i]
	add	$t1, $a1, $t3	# &str2[i]
	lb	$t1, 0($t1)	# c2 = str2[i]

	beq	$t0, $t1, my_strcmp_equal
	sub	$v0, $t0, $t1	# c1 - c2
	jr	$ra

my_strcmp_equal:

	bne	$t0, $0, my_strcmp_not_done
	li	$v0, 0
	jr	$ra

my_strcmp_not_done:

	add	$t3, $t3, 1	# i ++
	j	my_strcmp_loop

# puzzle solve ######################################################
#
# argument $a0: string to check against
# argument $a1: string to check # rotations
# return: rotations needed to match string 2 to string 1
puzzle_solve:

	sub	$sp, $sp, 20
	sw	$ra, 0($sp)		# save $ra and free up 4 $s registers for
	sw	$s0, 4($sp)		# str1
	sw	$s1, 8($sp)		# str2
	sw	$s2, 12($sp)    # length
	sw	$s3, 16($sp)	# i

	move	$s0, $a0	# str1
	move	$s1, $a1	# str2

	jal	my_strlen

	move 	$s2, $v0	# length
	li	$s3, 0			# i = 0

ps_loop:

	bgt	$s3, $s2, ps_return_minus_1
	move	$a0, $s0	# str1
	move	$a1, $s1	# str2
	jal	my_strcmp
	beq	$v0, $0, ps_return_i
	
	move	$a0, $s1	# str2
	jal	rotate_string_in_place
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

.kdata				           # interrupt handler data (separated just for readability)
chunkIH:	.space 8	       # space for four registers 
						       # TODO HOW MUCH SPACE
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"

.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		    # Get some free registers                  
	sw  $v0, 12($k0)   

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

	la  $a0, puzzles_received # set flag
	li  $v0, 1
	sw  $v0, 0($a0)

	sw  $v0, DELIVERY_ACKNOWLEDGE
	j interrupt_dispatch

non_intrpt:				    # was some non-interrupt

	li	$v0, PRINT_STRING_SYS
	la	$a0, non_intrpt_str
	syscall				    # print out an error message
	# fall through to done

done:

	la	$k0, chunkIH
	lw	$a0, 0($k0)		    # Restore saved registers
	lw  $v0, 12($k0)
	#lw  $t0, 8($k0)

.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret
