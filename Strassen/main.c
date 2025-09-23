#include "main.h"

/**
 * CODING STANDARDS:
 * 1. Avoid using complex libraries
 * 2. Structs are okay but should not have associated functions, i.e no methods
 */

int main(int argc, char **argv)
{
    if (argc != 3)
    {
        fprintf(stderr, "Usage: %s <dim1_rows> <dim2_cols>\n", argv[0]);
        return 1;
    }

    int dim1 = atoi(argv[1]);
    int dim2 = atoi(argv[2]);

    if (dim1 <= 0 || dim2 <= 0)
    {
        fprintf(stderr, "Error: dimensions must be positive integers.\n");
        return 1;
    }

    int *input_buffer_A = (int *)malloc(dim1 * dim2 * sizeof(int));
    int *input_buffer_B = (int *)malloc(dim1 * dim2 * sizeof(int));
    int i = 0;

    printf("Dim check : %d\n", dim1 * dim2);
    for (i = 0; i < (dim1 * dim2); i++)
    {
        input_buffer_A[i] = i;                 // Sequential values
        input_buffer_B[i] = (dim1 * dim2) - i; // Reverse sequential values
    }

    if (input_buffer_A == NULL || input_buffer_B == NULL)
    {
        fprintf(stderr, "Error: memory allocation failed.\n");
        free(input_buffer_A);
        free(input_buffer_B);
        return 1;
    }

    // Build and pad matrices, col_a = row_b for multiplication
    Matrix input_matrix_A = matrix_build(input_buffer_A, dim1, dim2);
    Matrix input_matrix_B = matrix_build(input_buffer_B, dim2, dim1);
    pad_matrix(&input_matrix_A, dim1, dim2, dim2, dim1);
    pad_matrix(&input_matrix_B, dim2, dim1, dim1, dim2);

    // Print matrices for debugging
    for (int i = 0; i < input_matrix_A.rows; i++)
    {
        for (int j = 0; j < input_matrix_A.cols; j++)
        {
            printf("%d ", input_matrix_A.matrix[i][j]);
        }
        printf("\n");
    }
    for (int i = 0; i < input_matrix_B.rows; i++)
    {
        for (int j = 0; j < input_matrix_B.cols; j++)
        {
            printf("%d ", input_matrix_B.matrix[i][j]);
        }
        printf("\n");
    }

    M_tree sub_Ms;
    int recursion_levels = (int)log2((input_matrix_A.rows < input_matrix_B.rows) ? input_matrix_B.rows : input_matrix_A.rows) - 1;
    Matrix result;
    result.rows = input_matrix_A.rows;
    result.cols = input_matrix_B.cols;
    result.matrix = (int **)malloc(result.rows * sizeof(int *));
    for (int i = 0; i < result.rows; i++)
    {
        result.matrix[i] = (int *)malloc(result.cols * sizeof(int));
    }
    partition(input_matrix_A, input_matrix_B, &sub_Ms, recursion_levels);
    compute_base(&sub_Ms);
    compute_result(&sub_Ms, &result, recursion_levels);

    free(input_buffer_A);
    free(input_buffer_B);
    free(result.matrix);
    return 0;
}
