# dbg

A lightweight graphical front-end for gdb

dbg is a simple, ultra-light debugger GUI interface for GDB. The debugger can be started from anywhere (but the project root seems a good idea). 

   dbg path/to/main.elf

The directory containing the executable becomes the default directory and root of the project. All pathes to source files are relative to this place. An project tree example can be:

   project
    +- include
    |   +- xxx.h
    |   `- yyy.h
    +- src
    |   +- xxx.c
    |   `- yyy.c
    +- Makefile
    `- main.elf
   

The GUI is just a window for the currently debugged/viewed source file and another for the log.
   
Commands can be sent to the gdb debugger, directly through the bottom 'GDB' entry or through the toolbar icons and the menu items. Commands sent are logged in the Log window, as well as their result. All gdb commands are available directly via the command/log window. Or use, Auto-step/Auto-next to animate-execute your program, hitting Escape to stop.

Only 1 file can be viewed at a time. But a hook in the file menu is provided to reference source files with the command 'open'
Though, 
      
   open src/main.c lib/*.c
    
will include, in the file menu, 'main.c' and all c files from the 'lib' directory. New files not referenced yet are added to the hook as you step in.
   
## Debugging session setup and .dbginit

The .dbginit file at the project root contains actions to be done before the debug session can start : reset of the board, connection handling to the target, loading the code, breakpoint on main ...
   
The first line, starting with #! gives the name of the debugger used. It must be available in the PATH of the system. Then all gdb valid commands can be used in the .dbginit script, as well as 'open' (not a gdb command).

* Config example to use the simulator (if available for the target architecture)
  
  ```
	#! arm-none-eabi-gdb
	open src/main.s startup/*.s
	target sim
	load
	tb main
	run
  ̀``
   
* Config example to connect to a bare-metal remote target

  ```
	#! arm-none-eabi-gdb
	open src/main.c lib/*.c
	target remote localhost:3333
	monitor soft_reset_halt
	monitor mww 0xE01FC040 2
	monitor mww 0xE01FC0C4 0x801817BE
	load
	tbreak main
	continue
  ```

## Debugging

While debugging, the current line to be executed is shown highlighted in blue. Breakpoints are in red, or orange if they are also the current line.

* Execution commands

	step, next, finish ... 
     
* Frame context : usefull to navigate up and down through the execution stack. Indeed, you can see the point the processor was interrupted by an IRQ before servicing it.

	up, down
     
* Breakpoints : double-click on the line (which toggles the line color) or with commands

	break main.c:34
	break 45
	break myfunc

  and
	
	tbreak main.c:34

  for a temporary breakpoint
     
	info break
  
  for a breakpoint list
     
## View the variables and memory

* Printing/setting variables/registers

	p a
	print a
	set a=3
	
	p/x a	-- hexa
	p/x $r0	-- hexa
	p/x list->item1
	p *(int*)var
	
* Watch a variable/register

     display var
     disp/x $pc
     
* Watchpoints

	watch *(int *) 0x600850
	watch a
	
	info watch

  for a list of watchpoints
     
* View memory: use the GUI
     
## Debugging native app

Nothing special to be done
	
	dbg main.elf 1 2 3
	
    input/output in console.
	
##  Debugging fork

## Debugging threaded code


v1.1.2 2020.05.31
- restart: reset the board without reflaflashing the microcontroller
- autoreload when the binary app is updated
- warning when using source files newer than the binary app

v1.1.1 2016.07.01
- add comand line args support for native applications (by Fabrice Harrouet)
- drop support for core debug
- fix: breakpoint display bug

v1.1.0 2016.06.28
- code cleanup
- the path to the executable is the root of the project. Source files path 
  are relative to this place and must be at the same level or in 
  subdirectories
- bug fixes
  * file normalization relative to executable place whenever possible
  * view the right source file when debug is paused


v1.0 2016.01.28 initial release
- heavily modified from an old version of tdb (v1.3) by Peter Mc Donald http://pdqi.com/

  The key ideas were :
  
  * Learn tcl/tk :-)
  * Make a cross-platform gdb front end with no other dependancy than the 
    basic tcl/tk found on every Linux distro. All the code in a single file.
  * Simplify the GUI : no editing, no project handling. A debugger should be
    used for debugging programs. Project handling through makefile. Just
    enough GUI to ease the developper's life. For everything else, rely on 
    gdb capability to connect to targets, view variables ...
  * Have a simple configuration format that largely rely on gdb to be able
    to debug any C/C++/asm program running on different target types from
    bare metal target to native programs, to embedded Linux targets debugged
    through the network.
    
- code simplification, GUI review, complete event handling review
- syntax highlighting through a modified version of the ctext megawidget
- balloon help
- .dbginit file contains the target connection parameters and gdb commands to
  be executed when loading the program (before user can interact with it)
- partial gdbmi protocol
- reload fonctionnality with breakpoints keeping
