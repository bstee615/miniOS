# miniOS, or BenjiZealOS
CpS 230 operating system team project

## Story of My Life
miniOS was a project for my CpS 230 Computer Systems class, taken Spring of 2017.
I worked on it with Jacob Brazeal, a great guy and solid programmer.
We spent way too much time on bugs my grandmother would have caught, but it was a learning experience.

This project was the most fun and frustration that I have felt in any programming project to date.
Thank you for looking at and sharing in this project - I am glad for it to see the light of day again.
It'll always hold a special place in my heart as my first intensive group effort.

## To Run:
1. Extract the contents of this .ZIP folder onto your computer.
2. Navigate to "\miniOS-release-pkg-2017\miniOS" and run "run.bat".
### Advanced instructions if you are NOT running Windows:
  - Run a shell and navigate to "\miniOS-release-pkg-2017\miniOS".
  - Run this command: "..\dbd\dbd.exe ."
  - After DosBox pops up, enter "BOOT BOOTDISK.IMG".
  - Voila! If that doesn't work then fiddle with it and you should get it.

## Program Specifications
  miniOS is written completely in NASM. It took place over a period of three weeks (read: 5 stressful sprints and the rest of the time spent in anxiety.)
The program is a miniature version of a multitasking operating system. It currently runs three tasks:
  - calc - a graphing calculator that uses Reverse Polish Notation for its operation.
    It offers functional support and one variable, named X.
  - rainbow - a graphical demo, mostly to show that we could juggle more than two tasks at once.
  - gol - Conway's Game of Life, played out over about 200 iterations last time I checked.

## BUGS
  - graphics only step forward once every key press. This is a fault of the way that we set up keyboard I/O interrupts.
