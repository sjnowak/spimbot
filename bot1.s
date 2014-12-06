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

.align 2 # 2 means a 2^2 byte alignment
array_planet_structs:
	.space 120 # allocate space for 120 bytes

.text

main:
	li $t0, 5
	sw $t0, VELOCITY
	lw $t0, LANDING_REQUEST
	li $t1, 0			# Planet index begins at zero

pick_planet:
	bne $t0, $t1, taking_off
	add $t1, $t1, 1
	blt $t1, 5 taking_off
	li $t1, 0
	 
taking_off:
	sw $zero, TAKEOFF_REQUEST

planet_info:
	la $t2, array_planet_structs 
	sw $t2, PLANETS_REQUEST
	add $t3, $t1, $t2		# Start of planet i's structs in memory
move_x:
	lw $t4, 8($t3)			# Load planet i's x coordinate 
	lw $t5, BOT_X			# Load the x coordinates of SPIMBot
	beq $t5, $t4, move_y
	blt $t5, $t4, go_right
	bgt $t5, $t4, go_left
move_y:
	lw $t4, 12($t3)			# Load planet i's y coordinate
	lw $t5, BOT_Y			# Load the y coordinates of SPIMBot
	beq $t5, $t4, landing
	blt $t5, $t4, go_up
	bgt $t5, $t4, go_down
	
go_right:
	li $t0, 0			
	sw $t0, ANGLE
	li $t0, 1
	sw $t0, ANGLE_CONTROL		# Absolute angle
	#add $t5, $t5, 1
	j move_x
go_left:
	li $t0, 180
	sw $t0, ANGLE
	li $t0, 1	
	sw $t0, ANGLE_CONTROL
	#add $t5, $t5, -1
	j move_x
go_up:
	li $t0, 90
	sw $t0, ANGLE
	li $t0, 1
	sw $t0, ANGLE_CONTROL
	#add $t5, $t5, 1
	j move_y
go_down:
	li $t0, 270
	sw $t0, ANGLE
	li $t0, 1
	sw $t0, ANGLE_CONTROL
	#add $t5, $t5, -1
	j move_y

landing:
	sw $zero, VELOCITY
check:
	la $t2, array_planet_structs 
	sw $t2, PLANETS_REQUEST
	add $t3, $t1, $t2
	lw $t4, 8($t3)
	lw $t5, 12($t3)
	lw $t6, BOT_X
	lw $t7, BOT_Y
	bne $t6, $t4, check
	bne $t7, $t5, check
	sw $zero, LANDING_REQUEST

loop_infinite:
	j loop_infinite

	
