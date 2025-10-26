#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define COLS 80
#define ROWS 25

#define DEAD ' '
#define ALIVE '#'

#define INIT_RATIO 4

#define STR(x) _STR(x)
#define _STR(x) #x

static void clearscr() { printf("\e[1;1H\e[2J"); }

static void print_row(char row[COLS]) { printf("%." STR(COLS) "s\n", row); }

static void print_grid(char grid[COLS * ROWS]) {
  for (int i = 0; i < ROWS; i++)
    print_row(grid + i * COLS);
}

static void init_grid(char grid[COLS * ROWS]) {
  for (int i = 0; i < COLS * ROWS; i++) {
    if (rand() % INIT_RATIO)
      grid[i] = DEAD;
    else
      grid[i] = ALIVE;
  }
}

static char get_state(char grid[COLS * ROWS], int row, int col) {
  if (row < 0 || row >= ROWS || col < 0 || col >= COLS)
    return DEAD;

  return grid[row * COLS + col];
}

static int alive_neighbours(char grid[COLS * ROWS], int idx) {
  int row = idx / COLS;
  int col = idx % COLS;
  int neighbours = 0;

  for (int i = -1; i <= 1; i++)
    for (int j = -1; j <= 1; j++)
      if (get_state(grid, row + i, col + j) == ALIVE)
        neighbours++;

  if (get_state(grid, row, col) == ALIVE)
    neighbours--;

  return neighbours;
}

static char next_state(char grid[COLS * ROWS], int idx) {
  int n = alive_neighbours(grid, idx);

  if (get_state(grid, idx / COLS, idx % COLS) == ALIVE) {
    if (n < 2 || n > 3)
      return DEAD;

    return ALIVE;
  }

  if (n == 3)
    return ALIVE;

  return DEAD;
}

static void update_grid(char grid[COLS * ROWS]) {
  char new[COLS * ROWS];

  for (int i = 0; i < COLS * ROWS; i++)
    new[i] = next_state(grid, i);

  memcpy(grid, new, COLS * ROWS);
}

int main() {
  char grid[COLS * ROWS];

  srand(time(0));
  init_grid(grid);

  do {
    clearscr();
    print_grid(grid);
    update_grid(grid);
  } while (getchar() != 'q');

  return 0;
}
