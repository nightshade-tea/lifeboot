#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define COLS 80
#define ROWS 25

#define DEAD ' '
#define ALIVE '#'

#define INIT_RATIO 10

#define STR(x) _STR(x)
#define _STR(x) #x

static void clearscr() {
  printf("\e[1;1H\e[2J");
}

static void print_row(char row[COLS]) {
  printf("%." STR(COLS) "s\n", row);
}

static void print_grid(char grid[COLS * ROWS]) {
  for (int i = 0; i < ROWS; i++)
    print_row(grid + i * COLS);
}

static void init_grid(char grid[COLS * ROWS]) {
  for (int i = 0; i < ROWS * COLS; i++) {
    if (rand() % INIT_RATIO)
      grid[i] = DEAD;
    else
      grid[i] = ALIVE;
  }
}

int main () {
  char grid[COLS * ROWS];

  srand(time(0));
  init_grid(grid);

  clearscr();
  print_grid(grid);

  return 0;
}
