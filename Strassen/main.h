#include <stdio.h>
#include <stdlib.h>
#include <math.h>

typedef struct
{
    int **matrix;  // 2D array to hold matrix values
    int rows;      // Number of rows
    int cols;      // Number of columns
    int processed; // Flag to indicate if this matrix has been processed
    int sig_r;     // Significant rows
    int sig_c;     // Significant columns

} Matrix;

// NOT USED YET
// typedef struct
// {
//     Matrix *stack;
//     int size;
// } MatrixStack;

// void push(MatrixStack *stack, Matrix mat)
// {
//     // For simplicity, we won't implement dynamic resizing of the stack
//     stack->stack = (Matrix *)realloc(stack->stack, sizeof(Matrix) * (stack->size + 1));
//     stack->stack[stack->size] = mat;
//     stack->size++;
// }

void matrix_init(Matrix *mat, int rows, int cols, int num_matrices)
{
    for (int i = 0; i < num_matrices; i++)
    {
        mat[i].rows = rows;
        mat[i].cols = cols;
        mat[i].sig_r = rows;
        mat[i].sig_c = cols;
        mat[i].processed = 0; // Initialize as not processed

        // Allocate memory for the 2D array
        mat[i].matrix = (int **)malloc(rows * sizeof(int *));
        for (int j = 0; j < rows; j++)
        {
            mat[i].matrix[j] = (int *)malloc(cols * sizeof(int));
        }
    }
}

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

void pad_matrix(Matrix *input_matrix, int rows, int cols)
{
    // Save actual dimensions
    input_matrix->sig_r = rows;
    input_matrix->sig_c = cols;

    // Dimensions must be a power of 2 for Strassen's algorithm
    input_matrix->rows = (int)pow(2, ceil(log2(rows)));
    input_matrix->cols = (int)pow(2, ceil(log2(cols)));

    // Allocate memory for the input_matrix->matrix
    input_matrix->matrix = (int **)realloc(input_matrix->matrix, input_matrix->rows * sizeof(int *));
    for (int i = rows; i < input_matrix->rows; i++)
    {
        input_matrix->matrix[i] = (int *)malloc(input_matrix->cols * sizeof(int));
    }

    // Fill the input_matrix->matrix
    for (int i = 0; i < input_matrix->rows; i++)
    {
        for (int j = 0; j < input_matrix->cols; j++)
        {

            if (i < input_matrix->sig_r && j < input_matrix->sig_c)
            {
                continue; // Retain original values
            }

            // Else pad with zeros
            input_matrix->matrix[i][j] = 0; // Padding with zeros
        }
    }
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
void calculate_M1(Matrix A11, Matrix A22, Matrix B11, Matrix B22, Matrix *intermediate)
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
    if (A_result.rows > 2 && A_result.cols > 2 && B_result.rows > 2 && B_result.cols > 2)
    {
        // Further partition and push to stack
        Matrix sub_matrices_A[4];
        Matrix sub_matrices_B[4];

        // Pad matrices if needed
        pad_matrix(&A_result, A_result.rows, A_result.cols);
        pad_matrix(&B_result, B_result.rows, B_result.cols);

        for (int i = 0; i < 4; i++)
        {
            sub_matrices_A[i] = matrix_partition(A_result, A_result.rows / 2, A_result.cols / 2, i);
            sub_matrices_B[i] = matrix_partition(B_result, B_result.rows / 2, B_result.cols / 2, i);
        }

        // Calculate M1 by using sub-matrices
        calculate_intermediates(sub_matrices_A, sub_matrices_B, intermediate);
    }
    else
    {
        // Base case: perform standard multiplication

        for (int i = 0; i < intermediate->rows; i++)
        {
            for (int j = 0; j < intermediate->cols; j++)
            {
                intermediate->matrix[i][j] = 0;
                for (int k = 0; k < A_result.cols; k++)
                {
                    intermediate->matrix[i][j] += A_result.matrix[i][k] * B_result.matrix[k][j];
                }
            }
        }
    }

    intermediate->processed = 1; // Mark as processed
}

// M2 = (A21 + A22) * B11, M5 = (A11 + A12) * B22
void calculate_M2_M5(Matrix A1, Matrix A2, Matrix B11, Matrix *intermediate, int index)
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
    if (A_result.rows > 2 && A_result.cols > 2)
    {
        // Further partition and push to stack
        Matrix sub_matrices_A[4];
        Matrix sub_matrices_B[4];

        // Pad matrices if needed
        pad_matrix(&A_result, A_result.rows, A_result.cols);
        pad_matrix(&B11, B11.rows, B11.cols);

        for (int i = 0; i < 4; i++)
        {
            sub_matrices_A[i] = matrix_partition(A_result, A_result.rows / 2, A_result.cols / 2, i);
            sub_matrices_B[i] = matrix_partition(B11, B11.rows / 2, B11.cols / 2, i);
        }

        // Recurse to calculate product for intermediate matrix
        calculate_intermediates(sub_matrices_A, sub_matrices_B, intermediate);
    }
    else
    {
        // Base case: perform standard multiplication
        for (int i = 0; i < intermediate->rows; i++)
        {
            for (int j = 0; j < intermediate->cols; j++)
            {
                intermediate->matrix[i][j] = 0;
                for (int k = 0; k < A_result.cols; k++)
                {
                    intermediate->matrix[i][j] += A_result.matrix[i][k] * B11.matrix[k][j];
                }
            }
        }
    }

    intermediate->processed = 1; // Mark as processed
}

// M3 = A11 * (B12 - B22),  M4 = A22 * (B21 - B11)
void calculate_M3_M4(Matrix A1, Matrix B1, Matrix B2, Matrix *intermediate, int index)
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
    if (B_result.rows > 2 && B_result.cols > 2)
    {
        // Further partition and push to stack
        Matrix sub_matrices_A[4];
        Matrix sub_matrices_B[4];

        // Pad matrices if needed
        pad_matrix(&A1, A1.rows, A1.cols);
        pad_matrix(&B_result, B_result.rows, B_result.cols);

        for (int i = 0; i < 4; i++)
        {
            sub_matrices_A[i] = matrix_partition(A1, A1.rows / 2, A1.cols / 2, i);
            sub_matrices_B[i] = matrix_partition(B_result, B_result.rows / 2, B_result.cols / 2, i);
        }

        // Recurse to calculate product for intermediate matrix
        calculate_intermediates(sub_matrices_A, sub_matrices_B, intermediate);
    }
    else
    {
        // Base case: perform standard multiplication

        for (int i = 0; i < intermediate->rows; i++)
        {
            for (int j = 0; j < intermediate->cols; j++)
            {
                intermediate->matrix[i][j] = 0;
                for (int k = 0; k < A1.cols; k++)
                {
                    intermediate->matrix[i][j] += A1.matrix[i][k] * B_result.matrix[k][j];
                }
            }
        }
    }

    intermediate->processed = 1; // Mark as processed
}

// M6 = (A21 - A11) * (B11 + B12), M7 = (A12 - A22) * (B21 + B22)
void calculate_M6_M7(Matrix A11, Matrix A22, Matrix B11, Matrix B22, Matrix *intermediate, int index)
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
    if (A_result.rows > 2 && A_result.cols > 2 && B_result.rows > 2 && B_result.cols > 2)
    {
        // Further partition and push to stack
        Matrix sub_matrices_A[4];
        Matrix sub_matrices_B[4];

        // Pad matrices if needed
        pad_matrix(&A_result, A_result.rows, A_result.cols);
        pad_matrix(&B_result, B_result.rows, B_result.cols);

        for (int i = 0; i < 4; i++)
        {
            sub_matrices_A[i] = matrix_partition(A_result, A_result.rows / 2, A_result.cols / 2, i);
            sub_matrices_B[i] = matrix_partition(B_result, B_result.rows / 2, B_result.cols / 2, i);
        }

        // Recurse to calculate product for intermediate matrix
        calculate_intermediates(sub_matrices_A, sub_matrices_B, intermediate);
    }
    else
    {
        // Base case: perform standard multiplication

        for (int i = 0; i < intermediate->rows; i++)
        {
            for (int j = 0; j < intermediate->cols; j++)
            {
                intermediate->matrix[i][j] = 0;
                for (int k = 0; k < A_result.cols; k++)
                {
                    intermediate->matrix[i][j] += A_result.matrix[i][k] * B_result.matrix[k][j];
                }
            }
        }
    }

    intermediate->processed = 1; // Mark as processed
}

void calculate_product(Matrix intermediates[7], Matrix *result, int dim1, int dim2)
{

    // Fill the result matrix using the intermediates
    for (int i = 0; i < result->rows; i++)
    {
        for (int j = 0; j < result->cols; j++)
        {
            if (i < result->rows / 2 && j < result->cols / 2) // C11 = M1 + M4 - M5 + M7
            {
                result->matrix[i][j] = intermediates[0].matrix[i][j] + intermediates[3].matrix[i][j] - intermediates[4].matrix[i][j] + intermediates[6].matrix[i][j];
            }
            else if (i < result->rows / 2 && j >= result->cols / 2) // C12 = M3 + M5
            {
                result->matrix[i][j] = intermediates[2].matrix[i][j - result->cols / 2] + intermediates[4].matrix[i][j - result->cols / 2];
            }
            else if (i >= result->rows / 2 && j < result->cols / 2) // C21 = M2 + M4
            {
                result->matrix[i][j] = intermediates[1].matrix[i - result->rows / 2][j] + intermediates[3].matrix[i - result->rows / 2][j];
            }
            else // C22 = M1 - M2 + M3 + M6
            {
                result->matrix[i][j] = intermediates[0].matrix[i - result->rows / 2][j - result->cols / 2] - intermediates[1].matrix[i - result->rows / 2][j - result->cols / 2] + intermediates[2].matrix[i - result->rows / 2][j - result->cols / 2] + intermediates[5].matrix[i - result->rows / 2][j - result->cols / 2];
            }
        }
    }
}

int calculate_intermediates(Matrix partitioned_matrices_A[4], Matrix partitioned_matrices_B[4], Matrix *result)
{

    // Initialize intermediates
    Matrix intermediates[7];
    matrix_init(intermediates, partitioned_matrices_A[0].rows, partitioned_matrices_B[0].cols, 7);

    // Compute intermediates
    calculate_M1(partitioned_matrices_A[0], partitioned_matrices_A[3], partitioned_matrices_B[0], partitioned_matrices_B[3], &intermediates[0]);
    calculate_M2_M5(partitioned_matrices_A[2], partitioned_matrices_A[3], partitioned_matrices_B[0], &intermediates[1], 1);
    calculate_M3_M4(partitioned_matrices_A[0], partitioned_matrices_B[1], partitioned_matrices_B[3], &intermediates[2], 2);
    calculate_M3_M4(partitioned_matrices_A[3], partitioned_matrices_B[2], partitioned_matrices_B[0], &intermediates[3], 3);
    calculate_M2_M5(partitioned_matrices_A[0], partitioned_matrices_A[1], partitioned_matrices_B[3], &intermediates[4], 4);
    calculate_M6_M7(partitioned_matrices_A[1], partitioned_matrices_A[0], partitioned_matrices_B[0], partitioned_matrices_B[1], &intermediates[5], 5);
    calculate_M6_M7(partitioned_matrices_A[1], partitioned_matrices_A[3], partitioned_matrices_B[2], partitioned_matrices_B[3], &intermediates[6], 6);

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

    // Once all intermediates are computed, compute the product
    calculate_product(intermediates, result, partitioned_matrices_A[0].rows, partitioned_matrices_B[0].cols);

    // Print the result matrix
    for (int i = 0; i < result->rows; i++)
    {
        for (int j = 0; j < result->cols; j++)
        {
            printf("Row: %d Col: %d Value: %d\n", i, j, result->matrix[i][j]);
        }
    }

    return 0; // Indicate success
}