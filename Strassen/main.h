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
    Matrix sub_ms[14]; // 14 sub-matrices for each node
    int size;

} Node;

typedef struct
{
    Node *tree;
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

void matrix_partition(Node current_node, Node *child_node, int new_rows, int new_cols,int M_idx)
{
    for (int sub_mat_idx = 0; sub_mat_idx < 14; sub_mat_idx++)
    {
        child_node->sub_ms[sub_mat_idx] = M_partition(current_node.sub_ms[M_idx + (sub_mat_idx % 2)], new_rows, new_cols, sub_mat_idx);
    }
}

void partition(Matrix input_matrix_A, Matrix input_matrix_B, M_tree *node_tree, int recursion_levels)
{

    int total_nodes = (int)pow(7, recursion_levels); // Total number of nodes on bottom level
    int total_sub_Ms = total_nodes * 14;             // Each node has 14 sub-matrices
    node_tree->size = total_nodes;
    node_tree->tree = (Node *)malloc(total_nodes * sizeof(Node));

    // Start with the root node
    int current_level = 0;
    int nodes_in_current_level = 1;
    int node_index = 0;
    node_tree->top_idx = 0;
    Matrix matrix_above = input_matrix_A;

    while (current_level <= recursion_levels)
    {
        int level_rows = matrix_above.rows / (int)pow(2, current_level + 1);
        int level_cols = matrix_above.cols / (int)pow(2, current_level + 1);

        for (int node = 0; node < nodes_in_current_level; node++)
        {
            for(int m = 0; m < 7; m++){

                int child_idx = node_tree->top_idx + nodes_in_current_level + (m * nodes_in_current_level) + node;
                matrix_partition(node_tree->tree[node_tree->top_idx + node], &node_tree->tree[child_idx], level_rows, level_cols,m*2);
            }
        }
    }
}

void compute_M(Matrix *sub_M, int M_index)
{
    Matrix A = sub_M[M_index * 2];     // First matrix for M1 to M7
    Matrix B = sub_M[M_index * 2 + 1]; // Second matrix for M1 to M7
    Matrix M_temp;
    M_temp.rows = A.rows;
    M_temp.cols = B.cols;

    // Allocate memory for the result matrix
    M_temp.matrix = (int **)malloc(M_temp.rows * sizeof(int *));
    for (int i = 0; i < M_temp.rows; i++)
    {
        M_temp.matrix[i] = (int *)malloc(M_temp.cols * sizeof(int));
    }

    // Perform standard matrix multiplication on A and B
    for (int i = 0; i < M_temp.rows; i++)
    {
        for (int j = 0; j < M_temp.cols; j++)
        {
            M_temp.matrix[i][j] = 0; // Initialize the cell
            for (int k = 0; k < A.cols; k++)
            {
                M_temp.matrix[i][j] += A.matrix[i][k] * B.matrix[k][j];
            }
        }
    }

    // Store M_temp in A to reuse memory
    sub_M[M_index * 2].matrix = M_temp.matrix;
    free(sub_M[M_index * 2 + 1].matrix);
    free(M_temp.matrix);
}

void compute_base(M_tree *sub_Ms, Matrix *result, int recursion_levels)
{
    int current_level = recursion_levels;
    int nodes_in_current_level = (int)pow(7, recursion_levels);

    for (int i = 0; i < nodes_in_current_level; i++)
    {
        // For each node in the current level, create 7 child nodes, where each node has 14 sub-matrices
        for (int j = 0; j < 7; j++)
        {
            compute_M(sub_Ms->tree[sub_Ms->top_idx + i].sub_ms, j);
        }
    }
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

void compute_result(M_tree *sub_Ms, Matrix *result, int recursion_levels)
{
    int current_level = recursion_levels;
    int nodes_in_current_level = (int)pow(7, recursion_levels);

    while (current_level >= 0)
    {
        for (int i = 0; i < nodes_in_current_level; i++)
        {
            Matrix intermediates[7];
            for (int j = 0; j < 7; j++)
            {
                intermediates[j] = sub_Ms->tree[sub_Ms->top_idx + i][j * 2]; // M1 to M7 are stored in even indices
            }

            // Calculate product and store result
            calculate_product(intermediates, sub_Ms->tree[sub_Ms->top_idx + i], result->rows, result->cols);
        }

        current_level--;
        nodes_in_current_level /= 7;
    }
}