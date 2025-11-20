@ ==============================================================================
@ ARM LAB 5 - TELLER MACHINE SIMULATION
@ ==============================================================================
@ Author: [Student Name Here]
@ Class: [Class Name]
@ Term: [Term]
@ Date: [Date]
@
@ Purpose: 
@   This program simulates an ATM. It manages an inventory of $20 and $10 bills
@   (50 of each initially). It processes user withdrawals up to $200, prioritizes
@   dispensing $20s, handles input validation, and provides a secret admin menu.
@
@ Build Commands:
@   as -o teller_machine.o teller_machine.s
@   gcc -o teller_machine teller_machine.o
@   ./teller_machine
@
@ ==============================================================================

.global main
.extern printf
.extern scanf

@ ==============================================================================
@ DATA SECTION
@ ==============================================================================
.data

    @ --- Constants and Limits ---
    MAX_TRANS:      .word 10
    MAX_WITHDRAW:   .word 200
    
    @ --- Inventory State (Memory Locations) ---
    count_20s:      .word 50        @ Initial: 50 bills
    count_10s:      .word 50        @ Initial: 50 bills
    
    @ --- Statistics ---
    trans_count:    .word 0         @ Valid transactions processed
    total_dist:     .word 0         @ Total cash distributed ($)
    dist_20s:       .word 0         @ Total $20s given out
    dist_10s:       .word 0         @ Total $10s given out
    
    @ --- Input Buffer ---
    user_input:     .word 0

    @ --- Output Strings ---
    str_welcome:    .asciz "\n--- ARM TELLER MACHINE ---\nWelcome. Withdrawals must be multiples of $10, max $200.\nEnter amount to withdraw: "
    str_input_fmt:  .asciz "%d"
    str_err_range:  .asciz "Error: Request must be between $10 and $200.\n"
    str_err_mult:   .asciz "Error: Request must be a multiple of $10.\n"
    str_err_fund:   .asciz "Error: Insufficient funds on hand for this amount. Please request less.\n"
    str_success:    .asciz "Dispensing: %d $20s and %d $10s.\n"
    
    @ --- Secret Menu Strings ---
    str_secret:     .asciz "\n*** SECRET MENU ***\nInventory $20s: %d\nInventory $10s: %d\nBalance on hand: $%d\nTrans count: %d\nTotal Distributed: $%d\n"
    
    @ --- End of Day Report ---
    str_closing:    .asciz "\n=== MACHINE CLOSING ===\n"
    str_rpt_trans:  .asciz "Total Valid Transactions: %d\n"
    str_rpt_20s:    .asciz "Total $20s Distributed:   %d\n"
    str_rpt_10s:    .asciz "Total $10s Distributed:   %d\n"
    str_rpt_cash:   .asciz "Total Cash Distributed:   $%d\n"
    str_rpt_rem:    .asciz "Remaining Funds on Hand:  $%d\n"

@ ==============================================================================
@ TEXT SECTION (CODE)
@ ==============================================================================
.text

main:
    push {ip, lr}           @ Save return address

loop_start:
    @ --------------------------------------------------------------------------
    @ Check Loop Termination Conditions
    @ --------------------------------------------------------------------------
    @ 1. Check Transaction Count
    ldr r0, =trans_count
    ldr r0, [r0]
    ldr r1, =MAX_TRANS
    ldr r1, [r1]
    cmp r0, r1
    bge end_program         @ If trans_count >= 10, end

    @ 2. Check Total Inventory (If 0 bills left, close)
    ldr r0, =count_20s
    ldr r0, [r0]
    ldr r1, =count_10s
    ldr r1, [r1]
    add r0, r0, r1          @ r0 = total bills remaining
    cmp r0, #0
    beq end_program

    @ --------------------------------------------------------------------------
    @ Prompt User
    @ --------------------------------------------------------------------------
    ldr r0, =str_welcome
    bl printf

    @ --------------------------------------------------------------------------
    @ Get Input
    @ --------------------------------------------------------------------------
    ldr r0, =str_input_fmt
    ldr r1, =user_input
    bl scanf

    ldr r1, =user_input
    ldr r4, [r1]            @ R4 holds the requested amount

    @ --------------------------------------------------------------------------
    @ Secret Code Check
    @ --------------------------------------------------------------------------
    cmp r4, #-9
    beq secret_mode

    @ --------------------------------------------------------------------------
    @ Input Validation
    @ --------------------------------------------------------------------------
    @ Check 1: Range ( > 0 and <= 200 )
    cmp r4, #0
    ble error_range         @ If <= 0
    ldr r1, =MAX_WITHDRAW
    ldr r1, [r1]
    cmp r4, r1
    bgt error_range         @ If > 200

    @ Check 2: Multiple of 10
    @ We simulate Modulo: Remainder = Num - (10 * (Num / 10))
    mov r1, #10
    sdiv r2, r4, r1         @ r2 = input / 10
    mul r3, r2, r1          @ r3 = r2 * 10
    sub r3, r4, r3          @ r3 = input - r3 (Remainder)
    cmp r3, #0
    bne error_multiple

    @ --------------------------------------------------------------------------
    @ Calculation Logic (Greedy Approach for $20s)
    @ --------------------------------------------------------------------------
    @ R4 = Requested Amount
    @ R5 = Need_20s
    @ R6 = Need_10s
    @ R7 = Available_20s (temp)
    @ R8 = Available_10s (temp)

    @ Load current inventory
    ldr r0, =count_20s
    ldr r7, [r0]
    ldr r0, =count_10s
    ldr r8, [r0]

    @ Step 1: Calculate max 20s needed
    mov r1, #20
    sdiv r5, r4, r1         @ R5 = Request / 20

    @ Step 2: Limit 20s to what is available
    cmp r5, r7
    ble calc_remainder      @ If needed <= available, good
    mov r5, r7              @ Else, take all available 20s

calc_remainder:
    @ Step 3: Calculate remaining amount to fill with 10s
    mov r1, #20
    mul r2, r5, r1          @ Amount covered by 20s
    sub r2, r4, r2          @ Remainder = Request - (Num_20s * 20)

    @ Step 4: Calculate 10s needed
    mov r1, #10
    sdiv r6, r2, r1         @ R6 = Remainder / 10

    @ Step 5: Check if we have enough 10s
    cmp r6, r8
    bgt error_funds         @ If needed 10s > available 10s, abort

    @ --------------------------------------------------------------------------
    @ Transaction Success - Commit Changes
    @ --------------------------------------------------------------------------
    
    @ Update Inventory 20s
    ldr r0, =count_20s
    ldr r1, [r0]
    sub r1, r1, r5          @ Current - Used
    str r1, [r0]

    @ Update Inventory 10s
    ldr r0, =count_10s
    ldr r1, [r0]
    sub r1, r1, r6
    str r1, [r0]

    @ Update Global Stats
    ldr r0, =trans_count
    ldr r1, [r0]
    add r1, r1, #1
    str r1, [r0]

    ldr r0, =total_dist
    ldr r1, [r0]
    add r1, r1, r4          @ Add request amount to total
    str r1, [r0]
    
    ldr r0, =dist_20s
    ldr r1, [r0]
    add r1, r1, r5
    str r1, [r0]
    
    ldr r0, =dist_10s
    ldr r1, [r0]
    add r1, r1, r6
    str r1, [r0]

    @ Print Success Message
    ldr r0, =str_success
    mov r1, r5              @ Num 20s
    mov r2, r6              @ Num 10s
    bl printf

    b loop_start            @ Return to main loop

@ ==============================================================================
@ Error Handlers
@ ==============================================================================
error_range:
    ldr r0, =str_err_range
    bl printf
    b loop_start

error_multiple:
    ldr r0, =str_err_mult
    bl printf
    b loop_start

error_funds:
    ldr r0, =str_err_fund
    bl printf
    b loop_start

@ ==============================================================================
@ Secret Menu (-9)
@ ==============================================================================
secret_mode:
    @ Calculate current balance on hand: (count_20s * 20) + (count_10s * 10)
    ldr r0, =count_20s
    ldr r1, [r0]            @ r1 = count 20s
    mov r2, #20
    mul r3, r1, r2          @ r3 = value of 20s
    
    ldr r0, =count_10s
    ldr r2, [r0]            @ r2 = count 10s
    mov r0, #10
    mul r0, r2, r0          @ r0 = value of 10s
    add r3, r3, r0          @ r3 = Total Balance

    @ Prepare Printf
    @ Format: Inventory $20s: %d, Inventory $10s: %d, Balance: %d, Trans: %d, Dist: %d
    
    @ We need to push arguments to stack for printf because we have > 3 args
    @ R0 = fmt, R1 = inv20, R2 = inv10, R3 = Balance. 
    @ Stack: TransCount, TotalDist
    
    ldr r0, =trans_count
    ldr r0, [r0]
    push {r0}               @ Push trans count (Arg 4)
    
    ldr r0, =total_dist
    ldr r0, [r0]
    push {r0}               @ Push total dist (Arg 5)
    
    ldr r0, =str_secret     @ Format String
    @ Reload registers for R1, R2, R3
    ldr r1, =count_20s
    ldr r1, [r1]
    ldr r2, =count_10s
    ldr r2, [r2]
    @ R3 already holds calculated balance

    bl printf
    add sp, sp, #8          @ Clean up stack (2 args * 4 bytes)

    b loop_start

@ ==============================================================================
@ End Program / Report
@ ==============================================================================
end_program:
    ldr r0, =str_closing
    bl printf

    @ Report Transactions
    ldr r0, =str_rpt_trans
    ldr r1, =trans_count
    ldr r1, [r1]
    bl printf

    @ Report 20s Distributed
    ldr r0, =str_rpt_20s
    ldr r1, =dist_20s
    ldr r1, [r1]
    bl printf
    
    @ Report 10s Distributed
    ldr r0, =str_rpt_10s
    ldr r1, =dist_10s
    ldr r1, [r1]
    bl printf
    
    @ Report Total Cash Distributed
    ldr r0, =str_rpt_cash
    ldr r1, =total_dist
    ldr r1, [r1]
    bl printf

    @ Report Remaining Funds on Hand
    @ Calculate: (count_20s * 20) + (count_10s * 10)
    ldr r0, =count_20s
    ldr r1, [r0]
    mov r2, #20
    mul r1, r2, r1          @ Value of 20s
    
    ldr r0, =count_10s
    ldr r2, [r0]
    mov r3, #10
    mul r2, r3, r2          @ Value of 10s
    add r1, r1, r2          @ Total
    
    ldr r0, =str_rpt_rem
    @ r1 already has the total
    bl printf

    @ Exit
    pop {ip, pc}
