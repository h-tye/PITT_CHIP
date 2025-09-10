#include <stdio.h>
#include <stdlib.h>

typedef struct
{
    int **matrix;
    int rows;
    int cols;

} Matrix;

typedef struct {
    Matrix *stack;
} MatrixStack;

Matrix matrix_build(int *input_buffer, int dim1, int dim2)
{
    Matrix mat;
    mat.rows = dim1;
    mat.cols = dim2;

    // Allocate memory for the 2D array
    mat.matrix = (int **)malloc(dim1 * sizeof(int *));
    for (int i = 0; i < dim1; i++)
    {
        mat.matrix[i] = (int *)malloc(dim2 * sizeof(int));
    }

    // Fill the 2D array with values from the input buffer
    for (int i = 0; i < dim1; i++)
    {
        for (int j = 0; j < dim2; j++)
        {
            mat.matrix[i][j] = input_buffer[i * dim2 + j];
        }
    }

    return mat;
}

Matrix matrix_partition(Matrix input_matrix, int new_rows, int new_cols, int quadrant)
{

    Matrix part;
    part.rows = new_rows;
    part.cols = new_cols;

    // Allocate memory for the partitioned matrix
    part.matrix = (int **)malloc(new_rows * sizeof(int *));
    for (int i = 0; i < new_rows; i++)
    {
        part.matrix[i] = (int *)malloc(new_cols * sizeof(int));
    }

    // Populate new matrix based on quadrant
    int row_offset = (quadrant / 2) * new_rows;
    int col_offset = (quadrant % 2) * new_cols;

    for (int i = 0; i < new_rows; i++)
    {
        for (int j = 0; j < new_cols; j++)
        {
            part.matrix[i][j] = input_matrix.matrix[i + row_offset][j + col_offset];
        }
    }

    return part;
}

void calculate_intermediates(Matrix partitioned_matrices[4], Matrix *intermediates[7])
{


}