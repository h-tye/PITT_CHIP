#define the C compiler to use
CC = gcc
#define comipler flags
CFLAGS = -std=c11 -Wall -fmax-errors=10 -Wextra
# define library paths in addition to /usr/lib
LFLAGS = -lm
# define libraries to use
LIBS =
# define the object files that this project needs
OBJFILES = main.o
# define the name of the executable file
MAIN = program

all: $(MAIN)

$(MAIN): $(OBJFILES)
	$(CC) $(CFLAGS) -o $(MAIN) $(OBJFILES) $(LFLAGS)
	
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<
# $@ means left of : and $< means right of :
	
clean:
	rm -f $(OBJFILES) $(MAIN)

launch: $(MAIN)
	./$(MAIN)

mem: $(MAIN)
	valgrind ./$(MAIN) 16 16