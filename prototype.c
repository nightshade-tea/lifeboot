#include <stdio.h>

#define COLS 80
#define ROWS 25

#define DEAD ' '
#define ALIVE '#'

#define STR(x) _STR(x)
#define _STR(x) #x

char grid[COLS * ROWS] = { [0 ... (COLS*ROWS-1)] = ALIVE };

static void print_row(char row[COLS]) {
  printf("%." STR(COLS) "s\n", row);
}

static void print_grid(char grid[COLS * ROWS]) {
  for (int i = 0; i < ROWS; i++)
    print_row(grid + i * COLS);
}

static void clearscr() {
  printf("\e[1;1H\e[2J");
}

int main () {
  clearscr();
  print_grid(grid);

  return 0;
}
