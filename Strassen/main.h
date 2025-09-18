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
    int level;     // Level in the recursion tree
    int M_value;   // M1 to M7

} Matrix;

typedef struct
{
    Matrix **tree;
    int size;
    int top_idx;
} M_tree;

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

void pad_matrix(Matrix *input_matrix, int rows_A, int cols_A, int rows_B, int cols_B)
{
    // Save actual dimensions
    input_matrix->sig_r = rows_A;
    input_matrix->sig_c = cols_A;

    // Dimensions must be a power of 2 for Strassen's algorithm
    input_matrix->rows = (int)pow(2, ceil(log2((rows_A < rows_B) ? rows_B : rows_A)));
    input_matrix->cols = (int)pow(2, ceil(log2((cols_A < cols_B) ? cols_B : cols_A)));

    // Allocate memory for the input_matrix->matrix
    input_matrix->matrix = (int **)realloc(input_matrix->matrix, input_matrix->rows * sizeof(int *));
    for (int i = rows_A; i < input_matrix->rows; i++)
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

void partition(Matrix input_matrix_A, Matrix input_matrix_B, M_tree *sub_Ms, int recursion_levels)
{

    int total_sub_Ms = (int)pow(7, recursion_levels);
    sub_Ms->size = total_sub_Ms;
    sub_Ms->tree = (Matrix **)malloc(total_sub_Ms * sizeof(Matrix *));
    for (int i = 0; i < total_sub_Ms; i++)
    {
        sub_Ms->tree[i] = (Matrix *)malloc(14 * sizeof(Matrix)); // Each node has 14 sub-matrices
    }

    // Start with the root node
    int current_level = 0;
    int nodes_in_current_level = 1;
    int node_index = 0;
    sub_Ms->top_idx = 0;

    // Initialize the root node
    matrix_partition(input_matrix_A, input_matrix_B, sub_Ms->tree[node_index], input_matrix_A.rows / 2, input_matrix_A.cols / 2);
    node_index++;

    while (current_level < recursion_levels)
    {
        int nodes_in_next_level = 0;

        for (int i = 0; i < nodes_in_current_level; i++)
        {
            // For each node in the current level, create 7 child nodes, where each node has 14 sub-matrices
            for (int j = 0; j < 7; j++)
            {
                if (node_index >= total_sub_Ms)
                {
                    break; // Prevent overflow
                }

                // Partition the matrices for the child node
                matrix_partition(sub_Ms->tree[i][j], sub_Ms->tree[i][j + 1], sub_Ms->tree[node_index], sub_Ms->tree[i][j].rows / 2, sub_Ms->tree[i][j].cols / 2);
                node_index++;
                nodes_in_next_level++;
            }
        }

        // Then clear the parent node as we no longer need it
        free(sub_Ms->tree[current_level]);
        sub_Ms->top_idx = (int)pow(7, current_level) + 1 + sub_Ms->top_idx;

        current_level++;
        nodes_in_current_level = nodes_in_next_level;
    }
}

void matrix_partition(Matrix input_matrix_A, Matrix input_matrix_B, Matrix *sub_M, int new_rows, int new_cols)
{

    for (int i = 0; i < 12; i++)
    {
        sub_M[i] = M_partition(((i % 2 == 0) ? input_matrix_A : input_matrix_B), new_rows, new_cols, i);
    }
}

Matrix M_partition(Matrix input_matrix, int new_rows, int new_cols, int M_subindex)
{

    Matrix part;
    part.rows = new_rows;
    part.cols = new_cols;
    part.M_value = (M_subindex + 1) / 2;

    // Allocate memory for the partitioned matrix
    part.matrix = (int **)malloc(new_rows * sizeof(int *));
    for (int i = 0; i < new_rows; i++)
    {
        part.matrix[i] = (int *)malloc(new_cols * sizeof(int));
    }

    switch (M_subindex)
    {

    case 0: // [A11 + A22]
    case 1: // [B11 + B22]
        for (int i = 0; i < new_rows; i++)
        {
            for (int j = 0; j < new_cols; j++)
            {
                part.matrix[i][j] = input_matrix.matrix[i][j] + input_matrix.matrix[i + new_rows][j + new_cols];
            }
        }
        break;

    case 2:  // [A21 + A22]
    case 13: // [B21 + B22]
        for (int i = 0; i < new_rows; i++)
        {
            for (int j = 0; j < new_cols; j++)
            {
                part.matrix[i][j] = input_matrix.matrix[i + new_rows][j] + input_matrix.matrix[i + new_rows][j + new_cols];
            }
        }
        break;

    case 3: // [B11]
    case 4: // [A11]
        for (int i = 0; i < new_rows; i++)
        {
            for (int j = 0; j < new_cols; j++)
            {
                part.matrix[i][j] = input_matrix.matrix[i][j];
            }
        }
        break;

    case 5:  // [B12 - B22]
    case 12: // [A12 - A22]
        for (int i = 0; i < new_rows; i++)
        {
            for (int j = 0; j < new_cols; j++)
            {
                part.matrix[i][j] = input_matrix.matrix[i][j + new_cols] - input_matrix.matrix[i + new_rows][j + new_cols];
            }
        }
        break;

    case 6: // [A22]
    case 9: // [B22]
        for (int i = 0; i < new_rows; i++)
        {
            for (int j = 0; j < new_cols; j++)
            {
                part.matrix[i][j] = input_matrix.matrix[i + new_rows][j + new_cols];
            }
        }
        break;

    case 7:  // [B21 - B11]
    case 10: // [A21 - A11]
        for (int i = 0; i < new_rows; i++)
        {
            for (int j = 0; j < new_cols; j++)
            {
                part.matrix[i][j] = input_matrix.matrix[i + new_rows][j] - input_matrix.matrix[i][j];
            }
        }
        break;

    case 8:  // [A12 + A11]
    case 11: // [B12 + B11]
        for (int i = 0; i < new_rows; i++)
        {
            for (int j = 0; j < new_cols; j++)
            {
                part.matrix[i][j] = input_matrix.matrix[i][j + new_cols] + input_matrix.matrix[i][j];
            }
        }
        break;

    default:
        printf("Error: Invalid sub-matrix index %d\n", M_subindex);
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
        pad_matrix(&A_result, A_result.rows, A_result.cols, B_result.rows, B_result.cols);
        pad_matrix(&B_result, B_result.rows, B_result.cols, A_result.rows, A_result.cols);

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
        pad_matrix(&A_result, A_result.rows, A_result.cols, B11.rows, B11.cols);
        pad_matrix(&B11, B11.rows, B11.cols, A_result.rows, A_result.cols);

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
        pad_matrix(&A1, A1.rows, A1.cols, B_result.rows, B_result.cols);
        pad_matrix(&B_result, B_result.rows, B_result.cols, A1.rows, A1.cols);

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
        pad_matrix(&A_result, A_result.rows, A_result.cols, B_result.rows, B_result.cols);
        pad_matrix(&B_result, B_result.rows, B_result.cols, A_result.rows, A_result.cols);

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
    calculate_M6_M7(partitioned_matrices_A[2], partitioned_matrices_A[0], partitioned_matrices_B[0], partitioned_matrices_B[1], &intermediates[5], 5);
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