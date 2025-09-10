#include <stdio.h>
#include <stdlib.h>

typedef struct
{
    int **matrix;
    int rows;
    int cols;
    int processed; // Flag to indicate if this matrix has been processed

} Matrix;

typedef struct
{
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

// M1 = (A11 + A22) * (B11 + B22)
void calculate_M1(Matrix A11, Matrix A22, Matrix B11, Matrix B22, Matrix *M1, MatrixStack *stack)
{

    // First instantiate new matrices to hold the sums
    Matrix A_result, B_result;
    A_result.rows = A11.rows;
    A_result.cols = A11.cols;
    B_result.rows = B11.rows;
    B_result.cols = B11.cols;
    A_result.matrix = (int **)malloc(A_result.rows * sizeof(int *));
    B_result.matrix = (int **)malloc(B_result.rows * sizeof(int *));
    for (int i = 0; i < A_result.rows; i++)
    {
        A_result.matrix[i] = (int *)malloc(A_result.cols * sizeof(int));
        B_result.matrix[i] = (int *)malloc(B_result.cols * sizeof(int));
    }

    // Now perform the sums
    for (int i = 0; i < A_result.rows; i++)
    {
        for (int j = 0; j < A_result.cols; j++)
        {
            A_result.matrix[i][j] = A11.matrix[i][j] + A22.matrix[i][j];
            B_result.matrix[i][j] = B11.matrix[i][j] + B22.matrix[i][j];
        }
    }

    // Check if further partitioning is needed
    if (A_result.rows > 1 && A_result.cols > 1 && B_result.rows > 1 && B_result.cols > 1)
    {
        // Further partition and push to stack
        Matrix sub_matrices_A[4];
        Matrix sub_matrices_B[4];

        for (int i = 1; i <= 4; i++)
        {
            sub_matrices_A[i - 1] = matrix_partition(A_result, A_result.rows / 2, A_result.cols / 2, i);
            sub_matrices_B[i - 1] = matrix_partition(B_result, B_result.rows / 2, B_result.cols / 2, i);
        }

        // Initialize new set of intermediates for recursion
        Matrix intermediates[7];
        calculate_intermediates(sub_matrices_A, sub_matrices_B, &intermediates, stack);
    }
    else
    {
        // Base case: perform standard multiplication
        M1->rows = A_result.rows;
        M1->cols = B_result.cols;
        M1->matrix = (int **)malloc(M1->rows * sizeof(int *));
        for (int i = 0; i < M1->rows; i++)
        {
            M1->matrix[i] = (int *)malloc(M1->cols * sizeof(int));
        }

        for (int i = 0; i < M1->rows; i++)
        {
            for (int j = 0; j < M1->cols; j++)
            {
                M1->matrix[i][j] = 0;
                for (int k = 0; k < A_result.cols; k++)
                {
                    M1->matrix[i][j] += A_result.matrix[i][k] * B_result.matrix[k][j];
                }
            }
        }

        M1->processed = 1; // Mark as processed

        return;
    }
}

// M2 = (A21 + A22) * B11, M5 = (A11 + A12) * B22
void calculate_M2_M5(Matrix A1, Matrix A2, Matrix B11, Matrix *M, MatrixStack *stack)
{

    // First instantiate new matrices to hold the sums
    Matrix A_result;
    A_result.rows = A1.rows;
    A_result.cols = A1.cols;
    A_result.matrix = (int **)malloc(A_result.rows * sizeof(int *));
    for (int i = 0; i < A_result.rows; i++)
    {
        A_result.matrix[i] = (int *)malloc(A_result.cols * sizeof(int));
    }

    // Now perform the sums
    for (int i = 0; i < A_result.rows; i++)
    {
        for (int j = 0; j < A_result.cols; j++)
        {
            A_result.matrix[i][j] = A1.matrix[i][j] + A2.matrix[i][j];
        }
    }

    // Check if further partitioning is needed
    if (A_result.rows > 1 && A_result.cols > 1)
    {
        // Further partition and push to stack
        Matrix sub_matrices_A[4];
        Matrix sub_matrices_B[4];

        for (int i = 1; i <= 4; i++)
        {
            sub_matrices_A[i - 1] = matrix_partition(A_result, A_result.rows / 2, A_result.cols / 2, i);
        }

        // Initialize new set of intermediates for recursion
        Matrix intermediates[7];
        calculate_intermediates(sub_matrices_A, sub_matrices_B, &intermediates, stack);
    }
    else
    {
        // Base case: perform standard multiplication
        M->rows = A_result.rows;
        M->cols = A_result.cols;
        M->matrix = (int **)malloc(M->rows * sizeof(int *));
        for (int i = 0; i < M->rows; i++)
        {
            M->matrix[i] = (int *)malloc(M->cols * sizeof(int));
        }

        for (int i = 0; i < M->rows; i++)
        {
            for (int j = 0; j < M->cols; j++)
            {
                M->matrix[i][j] = 0;
                for (int k = 0; k < A_result.cols; k++)
                {
                    M->matrix[i][j] += A_result.matrix[i][k] * B11.matrix[k][j];
                }
            }
        }

        M->processed = 1; // Mark as processed

        return;
    }
}

// M3 = A11 * (B12 - B22),  M4 = A22 * (B21 - B11)
void calculate_M3_M4(Matrix A1, Matrix B1, Matrix B2, Matrix *M, MatrixStack *stack)
{

    // First instantiate new matrices to hold the sums
    Matrix B_result;
    B_result.rows = B1.rows;
    B_result.cols = B2.cols;
    B_result.matrix = (int **)malloc(B_result.rows * sizeof(int *));
    for (int i = 0; i < B_result.rows; i++)
    {
        B_result.matrix[i] = (int *)malloc(B_result.cols * sizeof(int));
    }

    // Now perform the sums
    for (int i = 0; i < B_result.rows; i++)
    {
        for (int j = 0; j < B_result.cols; j++)
        {
            B_result.matrix[i][j] = B1.matrix[i][j] - B2.matrix[i][j];
        }
    }

    // Check if further partitioning is needed
    if (B_result.rows > 1 && B_result.cols > 1)
    {
        // Further partition and push to stack
        Matrix sub_matrices_A[4];
        Matrix sub_matrices_B[4];

        for (int i = 1; i <= 4; i++)
        {
            sub_matrices_A[i - 1] = matrix_partition(B_result, B_result.rows / 2, B_result.cols / 2, i);
        }

        // Initialize new set of intermediates for recursion
        Matrix intermediates[7];
        calculate_intermediates(sub_matrices_A, sub_matrices_B, &intermediates, stack);
    }
    else
    {
        // Base case: perform standard multiplication
        M->rows = B_result.rows;
        M->cols = B_result.cols;
        M->matrix = (int **)malloc(M->rows * sizeof(int *));
        for (int i = 0; i < M->rows; i++)
        {
            M->matrix[i] = (int *)malloc(M->cols * sizeof(int));
        }

        for (int i = 0; i < M->rows; i++)
        {
            for (int j = 0; j < M->cols; j++)
            {
                M->matrix[i][j] = 0;
                for (int k = 0; k < B_result.cols; k++)
                {
                    M->matrix[i][j] += B_result.matrix[i][k] * A1.matrix[k][j];
                }
            }
        }

        M->processed = 1; // Mark as processed

        return;
    }
}

// M6 = (A21 - A11) * (B11 + B12), M7 = (A12 - A22) * (B21 + B22)
void calculate_M6_M7(Matrix A11, Matrix A22, Matrix B11, Matrix B22, Matrix *M, MatrixStack *stack)
{
    // First instantiate new matrices to hold the sums
    Matrix A_result, B_result;
    A_result.rows = A11.rows;
    A_result.cols = A11.cols;
    B_result.rows = B11.rows;
    B_result.cols = B11.cols;
    A_result.matrix = (int **)malloc(A_result.rows * sizeof(int *));
    B_result.matrix = (int **)malloc(B_result.rows * sizeof(int *));
    for (int i = 0; i < A_result.rows; i++)
    {
        A_result.matrix[i] = (int *)malloc(A_result.cols * sizeof(int));
        B_result.matrix[i] = (int *)malloc(B_result.cols * sizeof(int));
    }

    // Now perform the sums
    for (int i = 0; i < A_result.rows; i++)
    {
        for (int j = 0; j < A_result.cols; j++)
        {
            A_result.matrix[i][j] = A11.matrix[i][j] - A22.matrix[i][j];
            B_result.matrix[i][j] = B11.matrix[i][j] + B22.matrix[i][j];
        }
    }

    // Check if further partitioning is needed
    if (A_result.rows > 1 && A_result.cols > 1 && B_result.rows > 1 && B_result.cols > 1)
    {
        // Further partition and push to stack
        Matrix sub_matrices_A[4];
        Matrix sub_matrices_B[4];

        for (int i = 1; i <= 4; i++)
        {
            sub_matrices_A[i - 1] = matrix_partition(A_result, A_result.rows / 2, A_result.cols / 2, i);
            sub_matrices_B[i - 1] = matrix_partition(B_result, B_result.rows / 2, B_result.cols / 2, i);
        }

        // Initialize new set of intermediates for recursion
        Matrix intermediates[7];
        calculate_intermediates(sub_matrices_A, sub_matrices_B, &intermediates, stack);
    }
    else
    {
        // Base case: perform standard multiplication
        M->rows = A_result.rows;
        M->cols = B_result.cols;
        M->matrix = (int **)malloc(M->rows * sizeof(int *));
        for (int i = 0; i < M->rows; i++)
        {
            M->matrix[i] = (int *)malloc(M->cols * sizeof(int));
        }

        for (int i = 0; i < M->rows; i++)
        {
            for (int j = 0; j < M->cols; j++)
            {
                M->matrix[i][j] = 0;
                for (int k = 0; k < A_result.cols; k++)
                {
                    M->matrix[i][j] += A_result.matrix[i][k] * B_result.matrix[k][j];
                }
            }
        }

        M->processed = 1; // Mark as processed

        return;
    }
}

int calculate_intermediates(Matrix partitioned_matrices_A[4], Matrix partitioned_matrices_B[4], Matrix *intermediates, MatrixStack *stack)
{

    // Compute
    calculate_M1(partitioned_matrices_A[0], partitioned_matrices_A[3], partitioned_matrices_B[0], partitioned_matrices_B[3], &intermediates[0], stack);
    calculate_M2_M5(partitioned_matrices_A[2], partitioned_matrices_A[3], partitioned_matrices_B[0], &intermediates[1], stack);
    calculate_M3_M4(partitioned_matrices_A[0], partitioned_matrices_B[1], partitioned_matrices_B[3], &intermediates[2], stack);
    calculate_M3_M4(partitioned_matrices_A[3], partitioned_matrices_B[2], partitioned_matrices_B[0], &intermediates[3], stack);
    calculate_M2_M5(partitioned_matrices_A[0], partitioned_matrices_A[1], partitioned_matrices_B[3], &intermediates[4], stack);
    calculate_M6_M7(partitioned_matrices_A[1], partitioned_matrices_A[0], partitioned_matrices_B[0], partitioned_matrices_B[1], &intermediates[5], stack);
    calculate_M6_M7(partitioned_matrices_A[1], partitioned_matrices_A[3], partitioned_matrices_B[2], partitioned_matrices_B[3], &intermediates[6], stack);

    // Ensure all intermediates have been processed
    for (int i = 0; i < 7; i++)
    {
        if (!intermediates[i].processed)
        {
            // Raise error
            printf("Error: Intermediate matrix M%d not processed.\n", i + 1);
            return -1; // Indicate error
        }
    }

    return 0; // Indicate success
}