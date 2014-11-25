# syscall constants
PRINT_INT_SYS = 1
PRINT_CHAR_SYS = 11
PRINT_STRING_SYS = 4

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

# planets array
.align 2
planets: .space 120

.text
# print int and space ##################################################
#
# argument $a0: number to print
# returns       nothing
print_int_and_space:
	li	$v0, PRINT_INT_SYS   # load the syscall option for printing ints
	syscall			         # print the number

	li   	$a0, ' '         # print a blank space
	li	$v0, PRINT_CHAR_SYS	 # load the syscall option for printing chars
	syscall			         # print the char
	   
	jr	$ra		             # return to the calling procedure

# print newline ########################################################
#
# no arguments
# returns       nothing

print_newline:
	li	$a0, '\n'		# print a newline char.
	li	$v0, PRINT_CHAR_SYS
	syscall	
	jr	$ra

# random planet selector ###############################################
#
# Generates a pseudo-random number between 0 and 4 
# using the Tausworth algorithm
#
# argument $a0: initial seed
# argument $a1: number of cycles to execute
rand: 

	# get the random number
	srl $t0, $a0, 13
	xor $a0, $a0, $t0

	sll $t0, $a0, 19
	xor $a0, $a0, $t0 # new seed

	sub $a1, $a1, 1 # i--
	bgt $a1, $0,  rand

	abs $a0, $a0
	
	# restrict the number to between 0 and 4
	li   $t0, 5
	div  $a0, $t0
	mfhi $v0

	jr $ra

# main function ########################################################
#
# no arguments
# returns       nothing

main:

	sub $sp, $sp, 4
	sw  $ra, 0($sp)

	lw  $s0, LANDING_REQUEST        # s0 = curr_planet
	beq $s0, -1, main_exit          # we're not on a planet

	li $s1, 200                     # s1 = seed
	li $s2, 5                       # s2 = cycles

	move $v0, $s0

next_planet_loop:

	bne  $v0, $s0, takeoff          # rand != curr_planet
	
	move $a0, $s1
	move $a1, $s2
	jal rand                        # v0 = rand

	add $s1, $s1, 1                 # change the seed
	j next_planet_loop

takeoff:

	move $s1, $v0                   # s1 = next_planet

	sw  $0,  TAKEOFF_REQUEST   # take off

	la $s2, planets
	sw $s2, PLANETS_REQUEST   # s2 = &planets[0]

	li   $t0, 24 
	mult $t0, $s1
	mflo $t0

	add  $s7, $t0, $s2              # s7 = &planets[next_planet]
	lw   $s3, 8($s7)                # s3 = planets[next_planet]->planet_x
	lw   $s4, 12($s7)               # s4 = planets[next_planet]->planet_y
            
change_x:

	lw   $s5, BOT_X             # s5 = bot_x
	beq  $s5, $s3, change_y

change_x_lt:

	bgt $s5, $s3, change_x_gt

	# face right
	sw  $0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL

	# set velocity
	li $t2, 10
	sw $t2, VELOCITY

change_x_lt_loop:

	bge $s5, $s3, change_y
	lw  $s5, BOT_X
	j change_x_lt_loop

change_x_gt:

	# face left
	li $t0, 180
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL

	# set velocity
	li $t2, 10
	sw $t2, VELOCITY

change_x_gt_loop:

	ble $s5, $s3, change_y
	lw  $s5, BOT_X
	j change_x_gt_loop

change_y:

	lw $s6, BOT_Y         # s6 = bot_y
	beq $s6, $s4, land

change_y_lt:

	bgt $s6, $s4, change_y_gt

	# face down
	li $t0, 90
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL

change_y_lt_loop:

	bge $s6, $s4, land
	lw  $s6, BOT_Y
	j change_y_lt_loop

change_y_gt:

	# face up
	li $t0, 270
	sw $t0, ANGLE
	li $t1, 1
	sw $t1, ANGLE_CONTROL

change_y_gt_loop:

	ble $s6, $s4, land
	lw  $s6, BOT_Y
	j change_y_gt_loop

land: 

	sw $0, VELOCITY

land_loop:
	
	la   $s7, planets
	sw   $s7, PLANETS_REQUEST     # s7 = &planets[0]
	li   $t0, 24 
	mult $t0, $s1
	mflo $t0
	add  $t0, $s7, $t0

	lw   $s3, 8($t0)  # planet_x
	lw   $s4, 12($t0) # planet_y
	lw   $s2, 4($t0)  # planet_radius
	sub  $s2, $s2, 2
	
	sub $t0, $s3, $s5
	abs $t0, $t0

	bge $t0, $s2, land_loop 

	sub $t0, $s4, $s6
	abs $t0, $t0

	bge $t0, $s2, land_loop

	# exited loop
	sw $0, LANDING_REQUEST

main_exit:

	j main_exit

	lw  $ra, 0($sp)
	add $sp, $sp, 4
	
	jr $ra
