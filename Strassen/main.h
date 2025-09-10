#include <stdio.h>
#include <stdlib.h>

typedef struct {
    int **matrix;
    int rows;
    int cols;
} Matrix;

Matrix matrix_partition(int *input_buffer, int dim1, int dim2) {
    Matrix mat;
    mat.rows = dim1;
    mat.cols = dim2;

    // Allocate memory for the 2D array
    mat.matrix = (int **)malloc(dim1 * sizeof(int *));
    for (int i = 0; i < dim1; i++) {
        mat.matrix[i] = (int *)malloc(dim2 * sizeof(int));
    }

    // Fill the 2D array with values from the input buffer
    for (int i = 0; i < dim1; i++) {
        for (int j = 0; j < dim2; j++) {
            mat.matrix[i][j] = input_buffer[i * dim2 + j];
        }
    }

    return mat;
}