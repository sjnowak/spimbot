# syscall constants (none yet, add as needed)

.data

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



# interrupt handler ###############################################
.kdata				           # interrupt handler data (separated just for readability)
chunkIH:	.space 8	       # space for four registers 
	
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

# 
delivery_interrupt:

	# TODO:
	# logic for interrupt:
	#
	# int i;
	# for (i = 0; i < 5; i++) {
	# 	if (puzzles[i] != NULL && !delivered_puzzles[i]) {
	# 		delivered_puzzles[i] = 1;	
	# 		break;
	# 	}
	# }

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
