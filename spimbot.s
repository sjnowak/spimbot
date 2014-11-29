# syscall constants (none yet, add as needed)

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

# main ############################################################
#
# arguments: none
# return: nothing
main: 

	# enable interrupts
	li	$t4, DELIVERY_MASK		   # delivery interrupt enable bit
	or	$t4, $t4, 1		           # global interrupt enable
	mtc0	 $t4, $12		       # set interrupt mask (Status register)

	# free up some registers
	sub $sp, $sp, __?
	sw  $s0, 0($sp)
	sw  $s1, 4($sp)
	sw  $s2, 8($sp)
	sw  $s3, 12($sp)

main_loop:

	li  $s0, 0         # i
	li  $s1, -1        # j

main_delv_check:

	bge $s0, 5, main_delv_success_check

	la  $t0, delivered_puzzles       # &delivered_puzzles[0]
	mul $t1, $s0, 4                  # i * 4
	add $t0, $t1, $t0                # &delivered_puzzles[i]
	lw  $t0, 0($t0)                  # delivered_puzzles[i]
	beq $t0, 0, main_delv_check_inc  # !delivered_puzzles[i]

main_delv_check_inc:

	add $s0, $s0, 1 # i++
	j   main_delv_check

main_delv_success_check:

	blt $s1, 0, main_find_planet
	# request planet info                  # TODO
	# move_to_planet(j)                    # TODO
	# solve_puzzles(j)                     # TODO

main_find_planet:

	li  $s0, 0 # i = 0

main_find_planet_loop:

	bge $s0, 5, main_loop

	la  $t0, pending_requests              # &pending_requests[0]
	mul $t1, $s0, 4                        # i * 4
	add $t0, $t1, $t0                      # &pending_requests[i]
	lw  $t0, 0($t0)                        # pending_requests[i]
	bne $t0, 0, main_find_planet_loop_inc  # pending_requests[i] != 0

	# move_to_planet(i)                    # TODO
	# request planet from planet i         # TODO

main_find_planet_loop_inc:

	add $s0, $s0, 1 # i++
	j main_find_planet_loop

# interrupt handler ###############################################
.kdata				           # interrupt handler data (separated just for readability)
chunkIH:	.space 12	       # space for three registers 
	
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
		sw  $t0, 0($a0)                 # delivered_puzzles[i] = 0
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

.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret