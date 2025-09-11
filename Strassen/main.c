#include "main.h"

/**
 * CODING STANDARDS:
 * 1. Avoid using complex libraries
 * 2. Arrays should be used instead of pointers where possible
 * 3. Structs are okay but should not have associated functions, i.e no methods
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
    if ((dim1 % 2) != 0 || (dim2 % 2) != 0)
    {
        fprintf(stderr, "Error: dimensions must be even for 2x2 partitioning.\n");
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

    Matrix input_matrix_A = matrix_build(input_buffer_A, dim1, dim2);
    Matrix input_matrix_B = matrix_build(input_buffer_B, dim1, dim2);

    Matrix partitioned_matrices_A[4];
    Matrix partitioned_matrices_B[4];

    for (int i = 0; i < 4; i++)
    {
        partitioned_matrices_A[i] = matrix_partition(input_matrix_A, dim1 / 2, dim2 / 2, i);
        partitioned_matrices_B[i] = matrix_partition(input_matrix_B, dim1 / 2, dim2 / 2, i);
    }

    MatrixStack *stack = (MatrixStack *)malloc(sizeof(MatrixStack));
    Matrix intermediates[7];
    calculate_intermediates(partitioned_matrices_A, partitioned_matrices_B, &intermediates, stack);

    // Print intermediates for debugging
    for (int i = 0; i < 7; i++)
    {
        printf("Intermediate M%d:\n", i + 1);
        for (int r = 0; r < intermediates[i].rows; r++)
        {
            for (int c = 0; c < intermediates[i].cols; c++)
            {
                printf("%d ", intermediates[i].matrix[r][c]);
            }
            printf("\n");
        }
        printf("\n");
    }

    Matrix result;
    calculate_product(intermediates, &result, dim1, dim2);

    // Print the result matrix
    for (int i = 0; i < result.rows; i++)
    {
        for (int j = 0; j < result.cols; j++)
        {
            printf("Row: %d Col: %d Value: %d\n", i, j, result.matrix[i][j]);
        }
    }

    free(input_buffer_A);
    free(input_buffer_B);
    free(stack);
    return 0;
}
