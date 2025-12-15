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

/**
 * Build a 2D matrix from a 1D input buffer
 * This is not needed, just more convenient for testing/visualization
 */
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

/**
 * Pad a matrix to the next power of 2 dimensions
 * Strassen algorithm requires matrices to be of size 2^n x 2^n
 * Room for optimizations
 */
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

/**
 * Lowest level parition function
 * Takes in a matrix and outputs a sub-matrix based on the M index
 * Designed to avoid having to create many temporary matrices for A11, A12, etc.
 */
void M_partition(Matrix input_matrix, Matrix *output_matrix, int new_rows, int new_cols, int M_subindex)
{
    // Need to update row/col info
    output_matrix->rows = new_rows;
    output_matrix->cols = new_cols;

    // Debug
    // for (int i = 0; i < new_rows; i++)
    // {
    //     for (int j = 0; j < new_cols; j++)
    //     {
    //         printf("M_partition: input_matrix[%d][%d] = %d\n", i, j, input_matrix.matrix[i][j]);
    //     }
    // }

    // See strassen algorithm slides for formulas
    switch (M_subindex)
    {

    case 0: // [A11 + A22] = M1a
    case 1: // [B11 + B22] = M1b
        for (int i = 0; i < (new_rows); i++)
        {
            for (int j = 0; j < (new_cols); j++)
            {
                output_matrix->matrix[i][j] = input_matrix.matrix[i][j] + input_matrix.matrix[i + new_rows][j + new_cols];
                // printf("M_partition case 0/1: output_matrix[%d][%d] = %d + %d = %d\n", i, j, input_matrix.matrix[i][j], input_matrix.matrix[i + new_rows][j + new_cols], output_matrix->matrix[i][j]);
            }
        }
        break;

    case 2:  // [A21 + A22] = M2a
    case 13: // [B21 + B22] = M7b
        for (int i = 0; i < (new_rows); i++)
        {
            for (int j = 0; j < (new_cols); j++)
            {
                output_matrix->matrix[i][j] = input_matrix.matrix[i + new_rows][j] + input_matrix.matrix[i + new_rows][j + new_cols];
            }
        }
        break;

    case 3: // [B11] = M2b
    case 4: // [A11] = M3a
        for (int i = 0; i < (new_rows); i++)
        {
            for (int j = 0; j < (new_cols); j++)
            {
                output_matrix->matrix[i][j] = input_matrix.matrix[i][j];
            }
        }
        break;

    case 5:  // [B12 - B22] = M3b
    case 12: // [A12 - A22] = M7a
        for (int i = 0; i < (new_rows); i++)
        {
            for (int j = 0; j < (new_cols); j++)
            {
                output_matrix->matrix[i][j] = input_matrix.matrix[i][j + new_cols] - input_matrix.matrix[i + new_rows][j + new_cols];
            }
        }
        break;

    case 6: // [A22] = M4a
    case 9: // [B22] = M5b
        for (int i = 0; i < (new_rows); i++)
        {
            for (int j = 0; j < (new_cols); j++)
            {
                output_matrix->matrix[i][j] = input_matrix.matrix[i + new_rows][j + new_cols];
            }
        }
        break;

    case 7:  // [B21 - B11] = M4b
    case 10: // [A21 - A11] = M6a
        for (int i = 0; i < (new_rows); i++)
        {
            for (int j = 0; j < (new_cols); j++)
            {
                output_matrix->matrix[i][j] = input_matrix.matrix[i + new_rows][j] - input_matrix.matrix[i][j];
            }
        }
        break;

    case 8:  // [A12 + A11] = M5a
    case 11: // [B12 + B11] = M6b
        for (int i = 0; i < (new_rows); i++)
        {
            for (int j = 0; j < (new_cols); j++)
            {
                output_matrix->matrix[i][j] = input_matrix.matrix[i][j + new_cols] + input_matrix.matrix[i][j];
            }
        }
        break;

    default:
        printf("Error: Invalid sub-matrix index %d\n", M_subindex);
    }
}

/**
 * Partitions the matrices for a given node into its child nodes
 * Each node has 14 sub-matrices, 2 adjacent sub-matrices will then form the child node
 * E.g. M1a and M1b of node above will form a new child node with 14 sub matrices
 * See strassen algorithm slides for more details
 */
void matrix_partition(Node current_node, Node *child_node, int new_rows, int new_cols, int M_idx)
{
    // Want to create 14 new sub-matrices for the child node
    for (int sub_mat_idx = 0; sub_mat_idx < 14; sub_mat_idx++)
    {
        // Pull MXa or MXb from parent node to form new sub-matrix
        M_partition(current_node.sub_ms[M_idx + (sub_mat_idx % 2)], &child_node->sub_ms[sub_mat_idx], new_rows, new_cols, sub_mat_idx);
    }
}

/**
 * Free memory allocated for a node's sub-matrices
 */
void destroy_node(Node *node)
{
    for (int i = 0; i < 14; i++)
    {
        for (int j = 0; j < node->sub_ms[i].rows; j++)
        {
            free(node->sub_ms[i].matrix[j]);
            node->sub_ms[i].matrix[j] = NULL;
        }
        free(node->sub_ms[i].matrix);
        node->sub_ms[i].matrix = NULL;
    }
    node->size = 0;
}

/**
 * Partition input matrices into 2x2 sub-matrices
 */
void partition(Matrix input_matrix_A, Matrix input_matrix_B, M_tree *node_tree, int partition_levels)
{

    int total_nodes = (int)pow(7, (partition_levels - 1)) + 1; // Total number of nodes on bottom level
    int total_sub_Ms = total_nodes * 14;                       // Each node has 14 sub-matrices
    node_tree->tree = (Node *)malloc(2 * total_nodes * sizeof(Node));
    for (int i = 0; i < total_nodes * 2; i++)
    {
        matrix_init(node_tree->tree[i].sub_ms, input_matrix_A.rows, input_matrix_A.cols, 14);
    }

    // Start with the root node
    int current_level = 0;
    int nodes_in_current_level = 1;
    int node_index = 0;
    node_tree->top_idx = 0;

    // Initialize the root node by partitioning the input matrices
    for (int m = 0; m < 14; m++)
    {
        M_partition(((m % 2 == 0) ? input_matrix_A : input_matrix_B), &node_tree->tree[0].sub_ms[m], (input_matrix_A.rows / 2), (input_matrix_A.cols / 2), m);
    }
    node_tree->size = 1;
    current_level++;

    Matrix matrix_above = node_tree->tree[0].sub_ms[0];
    for (; current_level < partition_levels; current_level++) // Iterate for partition levels number of times
    {
        int level_rows = matrix_above.rows / 2; // Update dimensions for next level
        int level_cols = matrix_above.cols / 2;

        for (int node = 0; node < nodes_in_current_level; node++) // Iterate through all nodes in current level
        {
            for (int m = 0; m < 7; m++) // For each node, create 7 child nodes
            {
                int child_idx = node_tree->top_idx + (nodes_in_current_level - node) + (7 * node) + m;
                matrix_partition(node_tree->tree[node_tree->top_idx], &node_tree->tree[child_idx], level_rows, level_cols, m * 2);
                node_tree->size++;
            }

            // Destroy parent node to free memory
            destroy_node(&node_tree->tree[node_tree->top_idx]);
            node_tree->size--;
            node_tree->top_idx++;
        }

        nodes_in_current_level *= 7;
        matrix_above = node_tree->tree[node_tree->top_idx].sub_ms[0];
    }
}

/***
 * Helper function to caluclate final product via intermediates
 */
void calculate_product(Matrix intermediates[7], Matrix *result, int dim1, int dim2)
{

    // Fill the result matrix using the intermediates
    for (int i = 0; i < dim1; i++)
    {
        for (int j = 0; j < dim2; j++)
        {
            if (i < dim1 / 2 && j < dim2 / 2) // C11 = M1 + M4 - M5 + M7
            {
                result->matrix[i][j] = intermediates[0].matrix[i][j] + intermediates[3].matrix[i][j] - intermediates[4].matrix[i][j] + intermediates[6].matrix[i][j];
            }
            else if (i < dim1 / 2 && j >= dim2 / 2) // C12 = M3 + M5
            {
                result->matrix[i][j] = intermediates[2].matrix[i][j - dim2 / 2] + intermediates[4].matrix[i][j - dim2 / 2];
            }
            else if (i >= dim1 / 2 && j < dim2 / 2) // C21 = M2 + M4
            {
                int temp2 = intermediates[1].matrix[i - dim1 / 2][j];
                int temp3 = intermediates[3].matrix[i - dim1 / 2][j];
                int temp4 = result->matrix[i][j];
                result->matrix[i][j] = intermediates[1].matrix[i - dim1 / 2][j] + intermediates[3].matrix[i - dim1 / 2][j];
            }
            else // C22 = M1 - M2 + M3 + M6
            {
                result->matrix[i][j] = intermediates[0].matrix[i - dim1 / 2][j - dim2 / 2] - intermediates[1].matrix[i - dim1 / 2][j - dim2 / 2] + intermediates[2].matrix[i - dim1 / 2][j - dim2 / 2] + intermediates[5].matrix[i - dim1 / 2][j - dim2 / 2];
            }
        }
    }

    result->rows = dim1;
    result->cols = dim2;
}

/**
 * Standard matrix multiplication for base case
 */
void matrix_mult(Matrix *A, Matrix *B, Matrix *C)
{

    int **temp_matrix = (int **)malloc(A->rows * sizeof(int *));
    for (int i = 0; i < A->rows; i++)
    {
        temp_matrix[i] = (int *)malloc(B->cols * sizeof(int));
        for (int j = 0; j < B->cols; j++)
        {
            temp_matrix[i][j] = 0; // Initialize to zero
        }
    }

    for (int i = 0; i < A->rows; i++)
    {
        for (int j = 0; j < B->cols; j++)
        {
            for (int k = 0; k < A->cols; k++)
            {
                temp_matrix[i][j] += A->matrix[i][k] * B->matrix[k][j];
                // printf("Multiplying A[%d][%d] * B[%d][%d] and adding to C[%d][%d]: %d * %d = %d\n", i, k, k, j, i, j, A->matrix[i][k], B->matrix[k][j], A->matrix[i][k] * B->matrix[k][j]);
            }
        }
    }

    // Copy the result to C
    for (int i = 0; i < A->rows; i++)
    {
        for (int j = 0; j < B->cols; j++)
        {
            C->matrix[i][j] = temp_matrix[i][j];
        }
    }

    // Free temporary matrix
    for (int i = 0; i < A->rows; i++)
    {
        free(temp_matrix[i]);
    }
    free(temp_matrix);
}

/**
 * Compute the base case multiplications of the 2x2 sub-matrices
 */
void compute_base(M_tree *tree)
{

    // Iterate through full bottom layer of sub_ms
    for (int node = tree->top_idx; node < tree->size + tree->top_idx; node++)
    {
 
        // Iterate through matrices within each node to form bottom layers Ms
        Matrix intermediates[7];
        for (int m = 0; m < 7; m++)
        {
            // Store result in same node, in idx % 7
            matrix_mult(&tree->tree[node].sub_ms[m * 2], &tree->tree[node].sub_ms[(m * 2) + 1], &tree->tree[node].sub_ms[m * 2]);
            intermediates[m] = tree->tree[node].sub_ms[m * 2];
        }

        // Calculate final product matrix for this node and store in head matrix
        calculate_product(intermediates, &tree->tree[node].sub_ms[1], tree->tree[node].sub_ms[1].rows * 2, tree->tree[node].sub_ms[1].cols * 2);
    }
}

/**
 * Compute the final result matrix from the computed Ms
 */
void compute_result(M_tree *tree, Matrix *result, int levels)
{

    int nodes_in_above_level = tree->size / 7;
    Matrix temp;

    while (nodes_in_above_level >= 1)
    {

        Matrix intermediates[7];
        // Iterate through full current layer of Ms
        for (int node = 0; node < nodes_in_above_level; node++)
        {
            for (int m = 0; m < 7; m++)
            {
                intermediates[m] = tree->tree[tree->top_idx + (node * 7) + m].sub_ms[1];
            }

            // Calculate final product matrix for this node and store in head matrix
            int parent_node_pos = tree->top_idx - nodes_in_above_level + node;
            matrix_init(&tree->tree[parent_node_pos].sub_ms[1], tree->tree[tree->top_idx + node].sub_ms[1].rows * 2, tree->tree[tree->top_idx + node].sub_ms[1].cols * 2, 1);
            calculate_product(intermediates, &tree->tree[parent_node_pos].sub_ms[1], tree->tree[parent_node_pos].sub_ms[1].rows, tree->tree[parent_node_pos].sub_ms[1].cols);
            temp = tree->tree[parent_node_pos].sub_ms[1];
        }

        tree->top_idx -= nodes_in_above_level;
        nodes_in_above_level /= 7;
    }

    // Copy the final result to the result matrix
    for (int i = 0; i < result->rows; i++)
    {
        for (int j = 0; j < result->cols; j++)
        {
            result->matrix[i][j] = tree->tree[tree->top_idx].sub_ms[1].matrix[i][j];
        }
    }
}