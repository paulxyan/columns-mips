######################## Bitmap Display Configuration ########################
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
##############################################################################

.data
ADDR_DSPL:
    .word 0x10008000

ADDR_KBRD:
    .word 0xffff0000

ColorArray:
    .word 0xFF0000   # red
    .word 0x00FF00   # green
    .word 0x0000FF   # blue
    .word 0xFFFF00   # yellow
    .word 0xFFB6C1   # light pink
    .word 0x800080   # purple
    
LIME_GREEN:
    .word 0x00FF00     # bright lime/green
PAUSE_BLACK:

  .word 0x000000
PAUSE_RED:
    .word 0xFFFFFF

.eqv BOARD_ROWS, 30
.eqv BOARD_COLS, 13
.eqv BOARD_CELLS, 390

NextPieces:
  .space 60
  
Board:
  .space 1560 # There are 390 words, and each word is 4 bytes. So we need 4 * 390 total spaces. s

BFS:
  .space 1560 # This is the BFS array that will allow us to do the BFS-style matching algorithm later. 

# This lets us store the current position of the row and column of the spawned piece.
PieceRow: .word 0  
PieceCol: .word 0   
PieceColors: .space 12  
GravityCounter: .word 0
GravitySpeed: .word 0
IncrementGravitySpeedTime: .word 0
IncrementGravitySpeedCounter: .word 0
GlobalPause: .word 0
GameStarted: .word 0

.text
.globl main

main:
    lw $t0, ADDR_KBRD
    lw $t2, 4($t0)
    
    sw $zero, GameStarted
    sw $zero, GravityCounter
    li $t3, 100
    sw $t3, IncrementGravitySpeedTime
    
    sw $zero, GlobalPause
    jal clear_board
    lw $a0, ADDR_DSPL
    jal draw_border
    jal draw_board
    jal spawn_three_pixels_top_half
    lw $t0, ADDR_KBRD
    
wait_for_difficulty_input:
    # hex codes: 0x31 for 1, 0x32 for 2, 0x33 for 3
    lw $t1, 0($t0)
    beq $t1, $zero, wait_for_difficulty_input
    lw $t2, 4($t0)
    
    li $t3, 0x31
    beq $t2, $t3, start_easy
    
    li $t3, 0x32
    beq $t2, $t3, start_medium
    
    li $t3, 0x33
    beq $t2, $t3, start_hard
    
    j wait_for_difficulty_input
    
start_easy:
   li $s0, 30
   sw $s0, GravitySpeed
   jal game_loop
   
start_medium:
    li $s0, 20
    sw $s0, GravitySpeed
    jal game_loop
    
start_hard:
    li $s0, 15
    sw $s0, GravitySpeed
    jal game_loop

exit:
    li $v0, 10
    syscall

draw_border:
    li $t7, 0x808080      
    li $t6, 15            
    li $t5, 128           
    
    move $t0, $a0 # start drawing
    li $t1, 0            

top_loop:
    beq $t1, $t6, top_done
    sw $t7, 0($t0)
    addi $t0, $t0, 4      
    addi $t1, $t1, 1
    j top_loop
    
top_done:
    li $t1, 31
    mul $t2, $t1, $t5     
    add $t0, $a0, $t2     # loads right values into our registers when we're done
    li $t1, 0

bottom_loop:
    beq $t1, $t6, bottom_done
    sw $t7, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    j bottom_loop
    
bottom_done:
    li $t1, 0 # loads 0 into the row so that we can continue with the execution. 
    
side_loop:
    beq $t1, 32, side_done

    # this draws the right column
    mul $t2, $t1, $t5
    add $t0, $a0, $t2
    sw $t7, 0($t0)

    # this does the left column
    addi $t0, $t0, 56
    sw $t7, 0($t0)

    addi $t1, $t1, 1
    j side_loop
    
side_done:
    jr $ra
    
# This loop allows us to draw all of the pieces into the bitmap
draw_board:
    lw $t0, ADDR_DSPL         # bitmap base
    li $t1, 128               # bytes per row
    la $t2, Board             # Board base

    li $t3, 0                 # r = 0
    
draw_board_row_loop:
    bge $t3, BOARD_ROWS, draw_board_done

    # Each time, we offset the column by 128. 
    li $t4, BOARD_COLS
    mul $t5, $t3, $t4          
    sll $t5, $t5, 2            
    addu $t6, $t2, $t5          # the desired offset is now calculated

    # Increments current row by 1, simulating a downward motions
    addi $t7, $t3, 1

    li $t8, 0                 # sets counter to 0
    
draw_board_col_loop:
    bge $t8, BOARD_COLS, draw_board_next_row

    # use the offset method to get the next column. Note that each row is 4 bits, so we 
    # need to offset by 4. 
    sll $t9, $t8, 2            # c * 4
    addu $s0, $t6, $t9          # load the color 
    lw $s1, 0($s0)            # color

    # increment the display column
    addi $s2, $t8, 1

    # jump to the appropriate index and change it 
    mul $s3, $t7, $t1          # displayRow * 128
    sll $s4, $s2, 2            # displayCol * 4
    addu $s3, $s3, $s4
    addu $s3, $s3, $t0

    sw $s1, 0($s3)            # Writes the 

    addi $t8, $t8, 1
    j draw_board_col_loop

draw_board_next_row:
    addi $t3, $t3, 1
    j draw_board_row_loop

draw_board_done:
    jr $ra

# random_color_index: selects a random index from 1-6, so that we can pick a color
random_color_index:
    li $v0, 42      
    li $a0, 0       
    li $a1, 6       
    syscall # This syscall lets us generate a random index from 1-6, so our colors are randomly generated. 
    move $v0, $a0
    jr $ra

# This spawns three pixels at the top of the board. 
spawn_three_pixels_top_half:
    # Save return address because we call random_color_index
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, ADDR_DSPL         # t0 = display base
     # Newly added
    li $t4, 128               # bytes per row

    la $t3, NextPieces       # base of queue
    la $t2, ColorArray       # base of colors
    # t0 = display base already set
    li $t4, 128              # bytes per row

    lw $t2, GameStarted
    bne $t2, $zero, queue_ready

    # when the game starts, fill up the NextPieces array with 15 random colors 
    la $t3, NextPieces       # loads base address of NextPieces into $t3
    li $t1, 0                # index i to range from 0-14

init_next_loop:
    beq $t1, 15, init_next_done

    jal random_color_index    # this will range from 0-5 (exclusive of 5)

    sll $t5, $t1, 2           # offset = i * 4
    addu $t6, $t3, $t5
    sw $v0, 0($t6)

    addi $t1, $t1, 1
    j init_next_loop

init_next_done:
    li $t2, 1
    sw $t2, GameStarted

queue_ready:
    la $t3, NextPieces       # stores memory location of NextPieces
    la $t2, ColorArray       # stores memory location of ColorArray
    la $t1, PieceColors      # this stores the 3 colors 
    li $t5, 0                # gets first 3 

load_piece_from_queue:
    beq $t5, 3, piece_colors_loaded

    # load the color index, using offset as 4 * j 
    sll $t6, $t5, 2           # calculates j * 4
    addu $t7, $t3, $t6
    lw $t8, 0($t7)           # t8 ranges from 0-4

    # lookup actual color by going to the desired index in ColorArray
    sll $t9, $t8, 2
    addu $t9, $t2, $t9
    lw $t8, 0($t9)           # t8 = actual 24-bit color

    # store into PieceColors at the index j, while acounting for the offset
    addu $t9, $t1, $t6
    sw $t8, 0($t9)

    addi $t5, $t5, 1
    j load_piece_from_queue

piece_colors_loaded:
    li $v0, 42
    li $a0, 0
    li $a1, 13
    syscall
    move $t1, $a0              # get a random number from 1-12
    addi $t1, $t1, 1           # increments by 1

    # Check 3rd row of this column on the display
    # calculate the offset using row * 128 + col * 4
    li $t2, 3                # display row 3
    mul $t3, $t2, $t4         # row * 128
    sll $t5, $t1, 2           # col * 4
    addu $t3, $t3, $t5
    addu $t3, $t3, $t0         # final address

    lw $t5, 0($t3)           # gets the color 3 positions down
    bne $t5, $zero, game_over      # if that top position is occupied, the game ends.s

    li $t2, 1                # top block at display row 1
    sw $t2, PieceRow
    sw $t1, PieceCol

    li $t3, 0                # i ranges from 0-2 because we want to get 3 colors

draw_falling_piece_loop:
    beq $t3, 3, falling_piece_done

    # rowDisplay = PieceRow + i
    addu $t5, $t2, $t3

    # load color from PieceColors at the ith position; then calculate offset
    la $t6, PieceColors
    sll $t7, $t3, 2           # i * 4
    addu $t6, $t6, $t7
    lw $t8, 0($t6)           # t8 = color

    # addr = base + row*128 + col*4
    mul $t9, $t5, $t4         # row*128
    sll $t7, $t1, 2           # col*4
    addu $t9, $t9, $t7
    addu $t9, $t9, $t0
    sw $t8, 0($t9)

    addi $t3, $t3, 1
    j draw_falling_piece_loop

falling_piece_done:
    # when we're done we need to advance forward by 3 spaces; 
    # shift everything to the left by 3. 
    la $t3, NextPieces
    li $t5, 0                # reset i to 0

shift_queue_loop:
    bge $t5, 12, shift_queue_done

    addi $t6, $t5, 3 # increment offset by 3 

    sll $t7, $t5, 2 # offset destination by 4 to get the address
    sll $t8, $t6, 2 # multiplies by 4 to attain this 

    addu $t9, $t3, $t8
    lw $t2, 0($t9)           # value from src

    addu $t9, $t3, $t7
    sw $t2, 0($t9)           # stores it into the destination 

    addi $t5, $t5, 1
    j shift_queue_loop

shift_queue_done:
    # Take 3 randomly generated values, and add it on to the back 
    li $t5, 12 # i will range from 12-14 
    
append_queue_loop:
    bge $t5, 15, append_queue_done

    jal random_color_index # fetches 3 randomly generated colors 

    sll $t7, $t5, 2
    addu $t9, $t3, $t7
    sw $v0, 0($t9)

    addi $t5, $t5, 1
    j append_queue_loop

append_queue_done:
    la $t3, NextPieces       # loads the base address of the queue
    la $t2, ColorArray       # loads base address of color array 
    # Note that $t0 stores the bitmap display base
    li $t4, 128              # bytes per row
    li $t6, 0                # piece index ranging from 0-4; total of 5 pieces
    
preview_piece_loop:
    bge $t6, 5, preview_done

    # gets the formula of a desired row using 5 + pieceIdx * 4
    li $t7, 4
    mul $t7, $t6, $t7         # piece index * 4 to get the offset 
    addi $t7, $t7, 5           # baseRow

    li $t8, 0                # color ranges from 0-3, as we're only interested in 3
    
preview_color_loop:
    bge $t8, 3, preview_next_piece

    # calculate offset using i * 3 + j
    li $t9, 3
    mul $t1, $t6, $t9         # i * 3
    addu $t1, $t1, $t8         # j 
    sll $t1, $t1, 2           # multiply by 4 to get the offset
    addu $t9, $t3, $t1
    lw $t2, 0($t9)           # load the color stored there into $t2

    la $v1, ColorArray
    # Now we use a similar procedure to calculate the offset
    # and find the desired position in ColorArray
    sll  $t2, $t2, 2           # i * 4
    addu $t2, $t2, $zero       # store it in $t2
    addu $t2, $t2, $v1  # fetches the color after calculating offset
    lw $t2, 0($t2)           # load the color stored there into $t2

    # the row we want to render this at is the base row (one we started at)
    # plus the index 
    addu $t9, $t7, $t8

    # col = 20 (right side of board)
    li $t1, 20

    # calculate the offset using row * 128 + col * 4
    mul $t9, $t9, $t4         # row * 128
    sll $t1, $t1, 2           # col * 4
    addu $t9, $t9, $t1
    addu $t9, $t9, $t0

    sw $t2, 0($t9)           # draw preview pixel

    addi $t8, $t8, 1
    j preview_color_loop

preview_next_piece:
    addi $t6, $t6, 1
    j preview_piece_loop

preview_done:
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# The game loop controls everything in the game, including re-rendering and keyboard controls.
game_loop:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, ADDR_KBRD # this is the address of the keyboard

game_loop_frame:
    # This code introduces a 16 millisecond delay, which allows us to re-render the screen 
    # every 16 ms (or 60 times per second)
    li $v0, 32
    li $a0, 16
    syscall
    
    lw $s3, IncrementGravitySpeedCounter
    addi $s3, $s3, 1
    sw $s3, IncrementGravitySpeedCounter
    lw $s3, IncrementGravitySpeedCounter 
    
    lw $s4, IncrementGravitySpeedTime
    
    beq $s3, $s4, DecrementGravityAndReset

    lw $s5, GravityCounter
    addi $s5, $s5, 1
    sw $s5, GravityCounter
    lw $s5 GravityCounter
    
    lw $s6, GravitySpeed

    beq $s5, $s6, Reset_Gravity

    lw $t1, 0($t0)            
    bne $t1, 1, game_loop_frame # this checks if the keyboard is ready to be read 

    # This lets us get the keyboard input
    lw $t2, 4($t0)            

    # Check if we got a 'q'. ASCII 'q' for 0x71; in this case quit the game. 
    li $t3, 0x71              
    beq $t2, $t3, game_loop_quit

    # Checks for 'a'. ASCII code for 'a' is 0x61.
    li $t3, 0x61              
    beq $t2, $t3, key_a

    # Checks for 's'. ASCII code for 's' is 0x73.
    li $t3, 0x73   
    beq $t2, $t3, key_s

    # Checks for 'd'. ASCII code for 'd' is 0x64
    li $t3, 0x64            
    beq $t2, $t3, key_d

    li $t3, 0x70
    beq $t2, $t3, key_p

    # Checks for 'w'. ASCII code for 'w' is 0x77
    li $t3, 0x77  
    beq $t2, $t3, key_w

    # Otherwise, we just continue with the game loop. 
    
    j game_loop_frame

# When we quit the game loop, we restore the stack and 
game_loop_quit:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# the S key moves the current position down by 1. 

Reset_Gravity:
    sw $zero, GravityCounter
    j key_s
  
DecrementGravityAndReset:
    sw $zero, IncrementGravitySpeedCounter
    sw $zero, GravityCounter
    
    lw $s1, GravitySpeed
    ble $s1, 2, decrement_done
    
    addi $s1, $s1, -1
    sw $s1, GravitySpeed
    
decrement_done:
    j game_loop_frame

key_p:
    la $s5, GlobalPause   # load address of GlobalPause
    lw $t1, 0($s5)        # load the value stored there into $t1
    bne $t1, $zero, un_pause

    j pause

pause:
    # This code draws the two pause bars 

    lw $t0, ADDR_DSPL      
    la $t1, PAUSE_RED
    lw $t1, 0($t1)        

    # start drawing the left pause bar; we start in row 1
    li   $t2, 1  
    li   $t3, 30            # col = 30
    mul  $t4, $t2, 128       # row * 128
    sll  $t5, $t3, 2         # col * 4
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw   $t1, 0($t6)         # draw red

    # draws in the second row 
    li $t2, 2              
    mul $t4, $t2, 128
    sll $t5, $t3, 2         
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)

    # Drawing at row 3; loads 1 into $t2 to represent the third row 
    li $t2, 3              
    mul $t4, $t2, 128
    sll $t5, $t3, 2         
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)

    # Draws the right bar 
    li $t2, 1              # draws to the first row 
    li $t3, 28             # goes into the 28th column 
    mul $t4, $t2, 128
    sll $t5, $t3, 2
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)

    # Draws to the second row 
    li   $t2, 2              
    mul  $t4, $t2, 128
    sll  $t5, $t3, 2     
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw   $t1, 0($t6)

    li   $t2, 3              # row = 1
    mul  $t4, $t2, 128
    sll  $t5, $t3, 2         # col 31 unchanged now since $t3 = 31
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw   $t1, 0($t6)
    
    li $v0, 32
    li $a0, 16
    syscall

    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)            
    bne $t1, 1, key_p

    # This lets us get the keyboard input
    lw $t2, 4($t0)    
    li $t3, 0x70
    bne $t2, $t3, pause
    # Otherwise, maintain the pause 
    
    li $s7, 1
    sw $s7, GlobalPause

    j key_p
  
  un_pause:
    lw $t0, ADDR_DSPL      # bitmap base address
    la $t1, PAUSE_BLACK
    lw $t1, 0($t1)         # red color

    # draw the first pause bar
    li $t2, 1              # row = 0
    li $t3, 30      # col = 30
    mul $t4, $t2, 128       # row * 128
    sll $t5, $t3, 2         # col * 4
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)         # draw red

    # shift down again
    li $t2, 2              # row = 1
    mul $t4, $t2, 128
    sll $t5, $t3, 2         # col 30 unchanged
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)

    # shifts down by 1
    li $t2, 3              # row = 1
    mul $t4, $t2, 128
    sll $t5, $t3, 2         # col 30 unchanged
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)

    # shifts down by 1
    li $t2, 1              # row = 0
    li $t3, 28          # col = 31
    mul $t4, $t2, 128
    sll $t5, $t3, 2
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)

    # shifts down again
    li $t2, 2              # row = 1
    mul $t4, $t2, 128
    sll $t5, $t3, 2         # col 31 unchanged now since $t3 = 31
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)

     # shifts down again
    li $t2, 3              # row = 1
    mul $t4, $t2, 128
    sll $t5, $t3, 2         # col 31 unchanged now since $t3 = 31
    addu $t6, $t0, $t4
    addu $t6, $t6, $t5
    sw $t1, 0($t6)
    
    sw $zero, GlobalPause
    j game_loop_frame

key_s:
    # first we load the display coordinates into the available temporary registers $t4, $t5.

    lw $t4, PieceRow  
    lw $t5, PieceCol         
    li $t8, 2 
    
# This examines the tiles below to see if we can move down to begin with. If not, pressing S doesn't do anything.
check_down_loop:
    blt $t8, 0, can_move_down

    # display row of this tile
    addu $t6, $t4, $t8         # dispRow = PieceRow + i
    addi $t6, $t6, 1           # belowDisp = dispRow + 1
    addi $v1, $t6, 1

    # Is the tile currently at the bottom?
    li $t7, 30
    bgt $t6, $t7, lock_piece_s   # If we're at the bottom, call the function that locks it in place at the bottom.

    # Here, we save the position. We decrement the values in $s0, $s1 to reflect the new positions of the piece.
    # Since no match was detected, we check down. 
    addi $s0, $t6, -1          
    addi $s1, $t5, -1          

    # This gets the desired square, using row * 13 + col, using the appropriate indices. 
    li $s2, BOARD_COLS
    mul $s3, $s0, $s2         # row * 13; this gets us our offset in the vertical direction. 
    addu $s3, $s3, $s1        # Then we add the number of columns to get us to the desired position in the board. 
    sll $s3, $s3, 2
    la $s4, Board
    addu $s3, $s3, $s4
    lw $s5, 0($s3)
    bne $s5, $zero, lock_piece_s  # Once we hit a tile, we call a function that wil  allow us 

    addi $t8, $t8, -1
    j check_down_loop

can_move_down:
    # Erase old piece from bitmap
    li $t8, 0
    li $t9, 128               # This stores how many bytes there are in a row; this constant is really important.

erase_down_loop:
    beq $t8, 3, erase_done_s

    addu $t6, $t4, $t8         # this determines how many spaces below we should erase. 

    # This segments calculates the address. 
    mul $t7, $t6, $t9         # row*128; this makes use of the of the stored 128 we used earlier. 
    sll $t1, $t5, 2           # col*4; We use a logical left shift for multiplication by two here. 
    addu $t7, $t7, $t1

    lw $t2, ADDR_DSPL
    addu $t7, $t7, $t2

    sw $zero, 0($t7)         # This erases the square above to be black, which allows the user to see that it was 
                               # erased. 
    addi $t8, $t8, 1
    j erase_down_loop # continues erasing until we have erased 3 times

erase_done_s:
    # Since we moved down, we increment the row position by 1 in our memory. 
    addi $t4, $t4, 1
    sw $t4, PieceRow

    # Earlier, $t8 was used to store the number of times we had to loop down. This time we use it 
    # to store the current number of times we have drawn, when it comes to drawing down. 
    li $t8, 0

draw_down_loop:
    beq $t8, 3, key_done # If we have drawn 3 times, we don't draw anymore and jump to key_done.

    addu $t6, $t4, $t8 # row = new top row + i

    # Now, we load in the correct color we're supposed to use for that piece.
    la $t3, PieceColors
    sll $t1, $t8, 2           # i * 4
    addu $t3, $t3, $t1
    lw $t2, 0($t3)            # color

    # Calculates the address using this formula: current position we're interested in is srow*128 + col*4
    li $t9, 128
    mul $t7, $t6, $t9
    sll $t1, $t5, 2
    addu $t7, $t7, $t1

    lw $t0, ADDR_DSPL
    addu $t7, $t7, $t0

    sw $t2, 0($t7)           # This draws onto the screen
    addi $t8, $t8, 1
    
    j draw_down_loop

key_w:
    # Play the desired sound effect when we shuffle!
    li $v0, 33
    li $a0, 70
    li $a1, 16
    li $a2, 60
    li $a3, 40
    
    syscall
    # This loads the current row + column into registers $t4, $t5. 
    
    lw $t4, PieceRow
    lw $t5, PieceCol

    # Erase current piece from bitmap
    li $t8, 0
    li $t9, 128

erase_w_loop:
    beq $t8, 3, erase_w_done

    addu $t6, $t4, $t8 # Adds the $t8 value to pieceRow

    # The formula we use is row * 128 + col * 4; recall that a board is 
    # technically a long array. 
    mul $t7, $t6, $t9         
    sll $t1, $t5, 2           
    addu $t7, $t7, $t1

    lw $t0, ADDR_DSPL
    addu $t7, $t7, $t0

    sw $zero, 0($t7)

    addi $t8, $t8, 1
    j erase_w_loop

erase_w_done:
    # Permutes the colors of the pieces, as done in the actual Columns
    la $t0, PieceColors
    lw $t1, 0($t0)      
    lw $t2, 4($t0)      
    lw $t3, 8($t0)      

    sw $t3, 0($t0)      
    sw $t1, 4($t0)      
    sw $t2, 8($t0)      

    # Set $t8 back to 0; $t8 helps store the variables we need to draw the pixel. 
    li $t8, 0

# After erasing, we need to redraw the piece into the new position. 
draw_w_loop:
    beq $t8, 3, key_done

    addu $t6, $t4, $t8

    la $t3, PieceColors
    sll $t1, $t8, 2
    addu $t3, $t3, $t1
    lw $t2, 0($t3)

    li $t9, 128
    mul $t7, $t6, $t9
    sll $t1, $t5, 2
    addu $t7, $t7, $t1

    lw $t0, ADDR_DSPL
    addu $t7, $t7, $t0

    sw $t2, 0($t7)

    addi $t8, $t8, 1
    j draw_w_loop # starts drawing the piece back again

# Always load PieceRow, PieceCol into $t4, $t5. This will be a common thing you will see as you read 
# this code!
key_a:
    lw $t4, PieceRow
    lw $t5, PieceCol

    # If we try to go right when pressing 'a' but we're at the boundary, don't do anything
    li $t6, 1
    beq $t5, $t6, key_done

    # Check collision: bottom-most tile one to the left
    lw $s0, PieceRow          
    lw $s1, PieceCol      
    addi $s0, $s0, 2            # bottom-most row (display)
    addi $s1, $s1, -1           # left column (display)

    # once again we get the desired bitmap index using row * 128 + col * 4 as the offset; recal lthat 
    # this is how we access these indices, as this is not a 2d array. 
    lw $s2, ADDR_DSPL        
    li $s3, 128
    mul $s4, $s0, $s3          # row * 128
    sll $s5, $s1, 2            # col * 4
    addu $s6, $s2, $s4
    addu $s6, $s6, $s5

    lw $s7, 0($s6)
    bne $s7, $zero, key_done   # If it's occupied, we cannot move left. 

    # After this, we call the function that starts erasing the piece. 
    li  $t8, 0
    li  $t9, 128

erase_left_loop:
    beq $t8, 3, erase_left_done # this function handles what happens when we're done erasing

    addu $t6, $t4, $t8

    mul $t7, $t6, $t9
    sll $t1, $t5, 2
    addu $t7, $t7, $t1

    lw $t2, ADDR_DSPL
    addu $t7, $t7, $t2

    sw $zero, 0($t7)

    addi $t8, $t8, 1
    j erase_left_loop

erase_left_done:
    # dcrements col after we're done
    addi $t5, $t5, -1
    sw $t5, PieceCol

    # draw piece at new column using PieceColors
    li  $t8, 0

draw_left_loop:
    beq $t8, 3, key_done

    addu $t6, $t4, $t8

    la $t3, PieceColors
    sll $t1, $t8, 2
    addu $t3, $t3, $t1
    lw $t2, 0($t3)

    li $t9, 128
    mul $t7, $t6, $t9
    sll $t1, $t5, 2
    addu $t7, $t7, $t1

    lw $t0, ADDR_DSPL
    addu $t7, $t7, $t0

    sw $t2, 0($t7)

    addi $t8, $t8, 1
    j draw_left_loop

# key_d moves the tile one to the left. As usual, we have a suite of 
# helper functions that do things like helping erase + redraw the tile, 
# and recalculate the new position
key_d:
    lw  $t4, PieceRow
    lw  $t5, PieceCol

    # boundary: right interior wall is col 13
    li  $t6, 13
    beq $t5, $t6, key_done

    # collision check: bottom tile to the right
    lw $s0, PieceRow
    lw $s1, PieceCol

    addi $s0, $s0, 2            # bottom row (display)
    addi $s1, $s1, 1            # right column (display)

    lw $s2, ADDR_DSPL
    li $s3, 128
    mul $s4, $s0, $s3
    sll $s5, $s1, 2
    addu $s6, $s2, $s4
    addu $s6, $s6, $s5

    lw $s7, 0($s6)
    bne $s7, $zero, key_done

    # This puts our data back in place for the next function,
    # which clears it out. This way it doesn't look like 
    # the two tiles are superimposed on each other
    li $t8, 0
    li $t9, 128

erase_right_loop:
    beq $t8, 3, erase_right_done

    addu $t6, $t4, $t8

    mul $t7, $t6, $t9
    sll $t1, $t5, 2
    addu $t7, $t7, $t1

    lw $t2, ADDR_DSPL
    addu $t7, $t7, $t2

    sw $zero, 0($t7)

    addi $t8, $t8, 1
    j erase_right_loop

erase_right_done:
    addi $t5, $t5, 1 # This saves the new x-position by 
                     # adding 1 to it 
    sw $t5, PieceCol
    li  $t8, 0

draw_right_loop:
    beq $t8, 3, key_done

    addu $t6, $t4, $t8

    la $t3, PieceColors
    sll $t1, $t8, 2
    addu $t3, $t3, $t1
    lw $t2, 0($t3)

    li $t9, 128
    mul $t7, $t6, $t9
    sll $t1, $t5, 2
    addu $t7, $t7, $t1

    lw $t0, ADDR_DSPL
    addu $t7, $t7, $t0

    sw $t2, 0($t7)

    addi $t8, $t8, 1
    j draw_right_loop

# key_done does all logic pertaining to what happens when a loop is done
# so that the game loop can continue. 
key_done:
    lw $t0, PieceRow
    add $t0, $t0, 3

    bge $t0, 31, lock_piece_s # If the row number is 31, we've hit a border. 

    lw $t0, PieceRow
    lw $t1, PieceCol

    # This following code computes the thing rows columns down. First, we need to 
    # add 3 to the current column number. 
    addi $t2, $t0, 3 
    li $t3, 128
    mul $t4, $t2, $t3

    sll $t5, $t1, 2 # multiplies the offset by 4
    lw $t6, ADDR_DSPL

    # This snippet offsets the column by the desired amount, and then adds
    # the column offset, which is stored in $t5. 
    addu $t7, $t6, $t4         
    addu $t7, $t7, $t5         

    lw $t8, 0($t7)           # This gets us the current color in the desired
                             # square, the one three rows beneath this one. 

    bne $t8, $zero, lock_piece_s # if it's not equal to a column, do the
                                 # lock_piece function. This function will contain 
                                 # a lot of what we need to carry out the matching, which is    
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j game_loop

# lock_piece_s handles all functionality after a collision where we can't move down anymore. 
lock_piece_s:
    li $v0, 33
    li $a0, 60
    li $a1, 16
    li $a2, 127
    li $a3, 127
    
    syscall

    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $t8, 0                   # Again, we store this value in $t8

lock_write_loop:
    beq $t8, 3, lock_after_write

    # we access the current row + column
    lw $t4, PieceRow
    lw $t5, PieceCol
    addu $t6, $t4, $t8           # get the new row 
    addi $t6, $t6, -1            # boardRow = dispRow - 1
    addi $t1, $t5, -1            # boardCol = dispCol - 1

    # This code snippet allows us to get the index 
    la $t3, PieceColors
    sll $t2, $t8, 2
    addu $t3, $t3, $t2
    lw $t7, 0($t3)

    # We access the index with boardRow * 13 + boardCol
    li $t2, BOARD_COLS
    mul $t4, $t6, $t2
    addu $t4, $t4, $t1
    sll $t4, $t4, 2

    la $t2, Board
    addu $t4, $t4, $t2
    sw $t7, 0($t4)

    addi $t8, $t8, 1
    j lock_write_loop

lock_after_write:
    # This handles what we do after we've finished matching
    jal draw_board
    jal match_gravity
    jal draw_board
    jal spawn_three_pixels_top_half
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j game_loop

clear_board:
    # Delete all state stored in the board array
    la  $t0, Board
    li  $t1, 0
    li  $t2, 390

clear_board_loop:
    beq $t1, $t2, clear_board_done
    sw  $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    j   clear_board_loop

clear_board_done:
    # this clears the bitmap address; addresses a bug
    # we had earlier with erasing both Gs on the board. 
    lw $t3, ADDR_DSPL  # bitmap base
    li $t4, 0          # row = 0

bitmap_clear_loop:
    beq $t4, 30, bitmap_clear_done   # stop when row = 30 
    li $t5, 0          # col = 0

bitmap_clear_col_loop:
    beq $t5, 32, bitmap_next_row # checks that we're still in bounds
    mul $t6, $t4, 128      # row * 128
    sll $t7, $t5, 2        # col * 4
    addu $t8, $t3, $t6      # offset is row * 128 + col * 4
    addu $t8, $t8, $t7
    sw $zero, 0($t8)      # paint pixel black

    addi $t5, $t5, 1
    j bitmap_clear_col_loop

bitmap_next_row:
    addi $t4, $t4, 1
    j bitmap_clear_loop

bitmap_clear_done:
    jr $ra      # Now return to caller
    
match_gravity:
match_outer:
    # When we're done, we need to clear out the BFS queue. 
    la $t0, BFS
    li $t1, 0
    li $t2, BOARD_CELLS
    
clear_queue_loop:
    beq $t1, $t2, clear_queue_done
    sw $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    j clear_queue_loop
    
clear_queue_done:
    li $s7, 0           
    la $s2, Board
    la $s3, BFS
    li $s0, 0               # pointer is 0
    
# This family of functions handles horizontal checking
horiz_row_loop:
    bge $s0, BOARD_ROWS, horiz_done
    li $s1, 0               # Resets the row counter to 0
    
horiz_col_loop:
    bge $s1, BOARD_COLS, horiz_next_row

    # Calculate the index as rows * 13 + cols. We need this here so we do NOT 
    # forget!
    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    addu $t3, $s2, $t2        # gets the desired position in the board using that offset we just calculated
    lw $t4, 0($t3)            # loads in the color 
    beq $t4, $zero, horiz_skip_advance

    # Check if this is the start of a run
    # If the column is greater than or equal to 0 and the one to the left is the
    # same color then a sequence of consecutive tiles has begun. 
    bgtz $s1, horiz_check_left
    j horiz_start_run

horiz_check_left:
    addi $t5, $s1, -1
    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $t5
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t6, 0($t3)
    beq $t6, $t4, horiz_skip_advance  # If it's the same color on the left, continue check

horiz_start_run:
    # run from c horizontally until we hit something different
    move $t5, $s1             # calculates the start of the run 
    addi $t6, $s1, 1          # increments the column by 1
    
horiz_run_loop:
    bge $t6, BOARD_COLS, horiz_run_done

    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $t6
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t7, 0($t3)
    bne $t7, $t4, horiz_run_done

    addi $t6, $t6, 1
    j horiz_run_loop

horiz_run_done:
    sub $t8, $t6, $t5        # length = c2 - runStart
    blt $t8, 3, horiz_no_mark

    li $s7, 1               # we have at least one match
    move $t9, $t5             # k = runStart

horiz_mark_loop:
    bge $t9, $t6, horiz_mark_done
    
    # Since our arrays are not two dimensional, we need to do this to 
    # compute the desired index, given the current row and column; a common 
    # theme throughout this code. 
    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $t9
    sll $t2, $t1, 2
    addu $t3, $s3, $t2 # updates the BFS queue
    li $t4, 1
    sw $t4, 0($t3)

    addi $t9, $t9, 1
    j horiz_mark_loop

horiz_mark_done:
horiz_no_mark:
    move $s1, $t6 # skip to end of run
    j horiz_col_loop

horiz_skip_advance:
    addi $s1, $s1, 1
    j horiz_col_loop

horiz_next_row:
    addi $s0, $s0, 1
    j horiz_row_loop

horiz_done:
    # This resets the horizontal counter back to 0
    li $s1, 0        
    
vert_col_loop:
    # This resets our vertical counter to 0
    bge $s1, BOARD_COLS, vert_done
    li $s0, 0              
    
vert_row_loop:
    bge $s0, BOARD_ROWS, vert_next_col

    # This uses the formula 13 * rows + cols to get the desired
    # offset for the index 
    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t4, 0($t3)          # color
    beq $t4, $zero, vert_skip_advance

    # start of vertical run?
    bgtz $s0, vert_check_up
    j vert_start_run

vert_check_up:
    addi $t5, $s0, -1
    li $t0, BOARD_COLS
    mul $t1, $t5, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t6, 0($t3)
    beq $t6, $t4, vert_skip_advance  # same color above → not start

vert_start_run:
    move $t5, $s0             # runStartRow
    addi $t6, $s0, 1          # r2 = r+1
    
vert_run_loop:
    bge $t6, BOARD_ROWS, vert_run_done

    li $t0, BOARD_COLS
    mul $t1, $t6, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t7, 0($t3)
    bne $t7, $t4, vert_run_done

    addi $t6, $t6, 1
    j vert_run_loop

vert_run_done:
    sub $t8, $t6, $t5        # length
    blt $t8, 3, vert_no_mark

    li $s7, 1               # found
    move $t9, $t5             # rMark = runStartRow

vert_mark_loop:
    bge $t9, $t6, vert_mark_done

    li $t0, BOARD_COLS
    mul $t1, $t9, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    addu $t3, $s3, $t2        # this updates the BFS array
    li $t4, 1
    sw $t4, 0($t3)

    addi $t9, $t9, 1
    j vert_mark_loop

vert_mark_done:
vert_no_mark:
    move $s0, $t6
    j vert_row_loop

vert_skip_advance:
    # This skips ahead vertically
    addi $s0, $s0, 1
    j vert_row_loop

vert_next_col:
    # This goes to the next column
    addi $s1, $s1, 1
    j vert_col_loop

vert_done:
    # This resets our row conter back to 0. 
    li $s0, 0       
    
diag_dr_row_loop:
    bge $s0, BOARD_ROWS, diag_dr_done
    li $s1, 0 # set column counter to 0
    
diag_dr_col_loop:
    bge $s1, BOARD_COLS, diag_dr_next_row

    # calculate the offset using 13 * row + col 
    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t4, 0($t3)          # color
    beq $t4, $zero, diag_dr_skip_advance

    # We check if this is the start of a diagonal run
    # We check if we're at the top row
    beqz $s0, diag_dr_start_run
    beqz $s1, diag_dr_start_run

    addi $t5, $s0, -1         # Decrements row by 1
    addi $t6, $s1, -1         # Decrements columns by 1
    li $t0, BOARD_COLS
    mul $t1, $t5, $t0
    addu $t1, $t1, $t6
    sll  $t2, $t1, 2
    addu $t3, $s2, $t2
    lw   $t7, 0($t3)
    beq  $t7, $t4, diag_dr_skip_advance   # same color above-left → not start

diag_dr_start_run:
    # run from (r,c) down-right while same color
    move $t5, $s0             # gets the current row from the saved registers
    move $t6, $s1             # gets the current col from the saved register
    
diag_dr_run_loop:
    addi $t8, $t5, 1          # nextRow
    addi $t9, $t6, 1          # nextCol
    bge $t8, BOARD_ROWS, diag_dr_run_done
    bge $t9, BOARD_COLS, diag_dr_run_done

    li $t0, BOARD_COLS
    mul $t1, $t8, $t0
    addu $t1, $t1, $t9
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t7, 0($t3)
    bne $t7, $t4, diag_dr_run_done

    move $t5, $t8             # advance along diag
    move $t6, $t9
    j diag_dr_run_loop

diag_dr_run_done:
    # calculates the length with (lastRow - startRow) + 1
    sub $t8, $t5, $s0
    addi $t8, $t8, 1
    blt $t8, 3, diag_dr_no_mark

    li $s7, 1                 # If we didn't branch, we found a found match
    move $t8, $s0             # markRow = startRow
    move $t9, $s1             # markCol = startCol
    
diag_dr_mark_loop:
    # fixes 
    li $t0, BOARD_COLS
    mul $t1, $t8, $t0
    addu $t1, $t1, $t9
    sll $t2, $t1, 2
    addu $t3, $s3, $t2
    li $t4, 1
    sw $t4, 0($t3)

    beq $t8, $t5, diag_dr_mark_done

    addi $t8, $t8, 1
    addi $t9, $t9, 1
    j diag_dr_mark_loop

diag_dr_mark_done:
diag_dr_no_mark:
    addi $s1, $s1, 1
    j diag_dr_col_loop

diag_dr_skip_advance:
    addi $s1, $s1, 1
    j diag_dr_col_loop

diag_dr_next_row:
    addi $s0, $s0, 1
    j diag_dr_row_loop

diag_dr_done:
    # loads 0 back into the row counter when we're done 
    li   $s0, 0             
    
diag_dl_row_loop:
    bge $s0, BOARD_ROWS, diag_dl_done
    li $s1, 0 # loads back the color counter 
    
diag_dl_col_loop:
    bge  $s1, BOARD_COLS, diag_dl_next_row

    # calculates the offset to get the desired position in the board
    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t4, 0($t3)          # color
    beq $t4, $zero, diag_dl_skip_advance

    # start of diag / run?
    # must be at top row OR rightmost col OR above-right != color
    beqz $s0, diag_dl_start_run
    li $t9, BOARD_COLS
    addi $t9, $t9, -1         # BOARD_COLS - 1
    beq  $s1, $t9, diag_dl_start_run

    # goes up by 1 index, to the right by one index
    addi $t5, $s0, -1         
    addi $t6, $s1, 1          
    bge $t6, BOARD_COLS, diag_dl_start_run   # out of bounds → treat as start

    # do the procedure to calculate the index 
    li $t0, BOARD_COLS
    mul $t1, $t5, $t0
    addu $t1, $t1, $t6
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t7, 0($t3)
    beq $t7, $t4, diag_dl_skip_advance # skips when we find one of the same color 

diag_dl_start_run:
    # run from (r,c) down-left while same color
    move $t5, $s0             # current row 
    move $t6, $s1             # current col 
diag_dl_run_loop:
    addi $t8, $t5, 1          # next row 
    addi $t9, $t6, -1         # next col 
    bge  $t8, BOARD_ROWS, diag_dl_run_done
    bltz $t9, diag_dl_run_done

    li $t0, BOARD_COLS
    mul $t1, $t8, $t0
    addu $t1, $t1, $t9
    sll $t2, $t1, 2
    addu $t3, $s2, $t2
    lw $t7, 0($t3)
    bne $t7, $t4, diag_dl_run_done

    move $t5, $t8
    move $t6, $t9
    j diag_dl_run_loop

diag_dl_run_done:
    # get the length of the diagonal by counting the number of matches
    # found in each direction 
    sub $t8, $t5, $s0
    addi $t8, $t8, 1
    blt $t8, 3, diag_dl_no_mark

    li $s7, 1               # found match
    move $t8, $s0           # the row we want to update startRow
    move $t9, $s1           # the col we want to update is startCol.
                            # This will be needed in the next function. 
                            
diag_dl_mark_loop:
    # We use the procedure again to calculate the offset
    li $t0, BOARD_COLS
    mul $t1, $t8, $t0
    addu $t1, $t1, $t9
    sll $t2, $t1, 2
    addu $t3, $s3, $t2
    li $t4, 1
    sw $t4, 0($t3)

    beq $t8, $t5, diag_dl_mark_done

    addi $t8, $t8, 1
    addi $t9, $t9, -1
    j diag_dl_mark_loop

diag_dl_mark_done:
diag_dl_no_mark:
    addi $s1, $s1, 1
    j diag_dl_col_loop

diag_dl_skip_advance:
    addi $s1, $s1, 1
    j diag_dl_col_loop

diag_dl_next_row:
    addi $s0, $s0, 1
    j diag_dl_row_loop

diag_dl_done:
    # We end if no matches are found
    beq $s7, $zero, match_done

    # This destroys all matched tiles
    la $t0, Board
    la $t1, BFS
    li $t2, 0
    li $t3, BOARD_CELLS

erase_matches_loop:
    beq $t2, $t3, erase_matches_done

    lw $t4, 0($t1)          # get value stored in the BFS array
    beq $t4, $zero, erase_skip_cell
    sw $zero, 0($t0)        # erase Board cell

erase_skip_cell:
    addi $t0, $t0, 4
    addi $t1, $t1, 4
    addi $t2, $t2, 1
    j erase_matches_loop

erase_matches_done:
    # This initializes the counter for the columns
    li $s1, 0               
    
col_gravity_loop:
    bge $s1, BOARD_COLS, gravity_all_done

    # readRow = BOARD_ROWS - 1, writeRow = BOARD_ROWS - 1
    li $s0, 29    # set the read row to be 29, signifying we're at the edge
    li $t5, 29    # set the write row to also be 29 (the edge)

col_read_loop:
    blt $s0, $zero, col_fill_top

    # We use the formula rows * 13 + cols to get the index 
    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    la $t3, Board
    addu $t3, $t3, $t2
    lw $t4, 0($t3)          # Reads the value after applying the offset

    beq $t4, $zero, col_read_next

    # Use our procedure to get rows * 13 + cols 
    li $t0, BOARD_COLS
    mul $t1, $t5, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    la $t6, Board
    addu $t6, $t6, $t2
    sw $t4, 0($t6)

    # clear original if moved
    bne $t5, $s0, col_zero_read
    j col_after_move
    
col_zero_read:
    sw $zero, 0($t3)

col_after_move:
    addi $t5, $t5, -1

col_read_next:
    addi $s0, $s0, -1
    j col_read_loop

col_fill_top:
    # fill 0..writeRow with 0
    blt  $t5, $zero, col_next
    li $s0, 0
    
col_zero_top_loop:
    bgt  $s0, $t5, col_next

    li $t0, BOARD_COLS
    mul $t1, $s0, $t0
    addu $t1, $t1, $s1
    sll $t2, $t1, 2
    la $t3, Board
    addu $t3, $t3, $t2
    sw $zero, 0($t3)

    addi $s0, $s0, 1
    j col_zero_top_loop

col_next:
    addi $s1, $s1, 1
    j col_gravity_loop

gravity_all_done:
    jal draw_board
    j match_outer # This continues the matching process

match_done:
    # If there are no matches, we decide what the next step should be. 
    # If a game-over condition is met, end the game loop and exit.
    # If not, spawn a new one at the top. 
    
    lw $t1, PieceCol           # loads the current column
    
    li $t4, 1                  # loads the current row
    li $t5, 128                # loads the number of bytes there are in a row 

    # We need to load the base address
    lw $t0, ADDR_DSPL       
    
    # this block calculates the offset using this formula: (row * 128) + (col * 4)
    # In this case, we're interested in knowing the value of the pixel
    # at the top of the current row. 
 
    mul $t2, $t4, $t5     
    sll $t3, $t1, 2       
    addu $t0, $t0, $t2         
    addu $t0, $t0, $t3         

    # This time we check the color at the top of the bitmap 
    lw $t3, 0($t0) 

    # Is the top pixel occupied?
    bne $t3, $zero, game_over  # This means that entire column is full, so we end the game. 
 
    jal spawn_three_pixels_top_half
    j game_loop

    li $s0, 0 # set the y-position of the current pixel back to 0 
    
game_over:
    # This time, we first reset the bitmap to black
    lw $t0, ADDR_DSPL         # display base
    li $t1, 0                 # row = 0
    li $t4, 32                # store bounds in registers
    li $t5, 32                # store bounds in registers
    li $t9, 128               # bytes per row

clear_row_loop:
    beq $t1, $t4, game_over_draw_letters  # if we've done it 32 times, we're done
    li $t2, 0                 # col = 0
    
clear_col_loop:
    # calculating the offset using row * 128 + col * 4
    mul $t3, $t1, $t9
    sll $t6, $t2, 2
    addu $t7, $t0, $t3
    addu $t7, $t7, $t6

    sw $zero, 0($t7)

    addi $t2, $t2, 1
    blt $t2, $t5, clear_col_loop

    addi $t1, $t1, 1
    j clear_row_loop

game_over_draw_letters:
    # this one draws the two Gs
    li $a0, 10        # top row for first G
    li $a1, 10        # left column for first G
    jal draw_G

    li $a0, 10        # same row
    li $a1, 18        # shifted right for second G
    jal draw_G
    
wait_for_difficulty_r:
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    beq $t1, $zero, wait_for_difficulty_r
    
    lw $t2, 4($t0)
    li $t3, 0x72
    beq $t2, $t3, main    # Goes back to main, and starts everything over. 
    
    j wait_for_difficulty_r
    
draw_G:
    lw $t0, ADDR_DSPL   
    la $t1, LIME_GREEN
    lw $t1, 0($t1)            
    li $t2, 128 # bytes per row

    move $t3, $a0               # top row
    move $t4, $a1               # left column
    move $t5, $t4               # current column
    
drawG_top_row_loop:
    # get offset using row * 128 + col * 4
    mul $t6, $t3, $t2
    sll $t7, $t5, 2
    addu $t8, $t0, $t6
    addu $t8, $t8, $t7
    sw $t1, 0($t8)

    addi $t5, $t5, 1
    addi $t9, $t4, 3            # limit col = left + 5
    blt $t5, $t9, drawG_top_row_loop

    li $t5, 0                 # the rows go from 0-6 to make a 7 pixel long bar
    
drawG_left_col_loop:
    addu $t6, $t3, $t5          # row = top + r
    mul $t7, $t6, $t2
    sll $t8, $t4, 2            # col = left
    addu $t7, $t7, $t8
    addu $t7, $t7, $t0
    sw $t1, 0($t7)

    addi $t5, $t5, 1
    blt  $t5, 7, drawG_left_col_loop

    # top horizontal bar 
    addi $t6, $t3, 6            # bottom row
    move $t5, $t4               # col = left
    
drawG_bottom_row_loop:
    mul $t7, $t6, $t2
    sll $t8, $t5, 2
    addu $t9, $t0, $t7
    addu $t9, $t9, $t8
    sw $t1, 0($t9)

    addi $t5, $t5, 1
    addi $t8, $t4, 5
    blt $t5, $t8, drawG_bottom_row_loop

    # makes a row 3 pixels long
    addi $t6, $t3, 3            # mid row
    addi $t5, $t4, 2            # start col
    
drawG_mid_row_loop:
    mul $t7, $t6, $t2
    sll $t8, $t5, 2
    addu $t9, $t0, $t7
    addu $t9, $t9, $t8
    sw $t1, 0($t9)

    addi $t5, $t5, 1
    addi $t8, $t4, 5
    blt $t5, $t8, drawG_mid_row_loop

    addi $t8, $t4, 4            # right col
    li $t5, 3                 # goes from 3-6 to make a 4 pixel long bar
    
drawG_right_col_loop:
    addu $t6, $t3, $t5          # row = top + offset
    mul $t7, $t6, $t2
    sll $t9, $t8, 2
    addu $t7, $t7, $t9
    addu $t7, $t7, $t0
    sw $t1, 0($t7)

    addi $t5, $t5, 1
    blt $t5, 7, drawG_right_col_loop

    jr $ra
