#include "main.h"

/**
 * CODING STANDARDS:
 * 1. Avoid using complex libraries
 * 2. Arrays should be used instead of pointers where possible
 * 3. Structs are okay but should not have associated functions, i.e no methods
 */

int main(int dim1, int dim2)
{

    // Define input array structure, temporaray until I/O implemented
    int *input_buffer_A = (int *)malloc(dim1 * dim2 * sizeof(int));
    int *input_buffer_B = (int *)malloc(dim1 * dim2 * sizeof(int));

    Matrix input_matrix_A = matrix_build(input_buffer_A, dim1, dim2);
    Matrix input_matrix_B = matrix_build(input_buffer_B, dim1, dim2);

    Matrix partitioned_matrices_A[4]; // First 4 partitions of the matrix
    Matrix partitioned_matrices_B[4]; // First 4 partitions of the matrix

    for (int i = 1; i <= 4; i++)
    {
        partitioned_matrices_A[i - 1] = matrix_partition(input_matrix_A, dim1 / 2, dim2 / 2, i);
        partitioned_matrices_B[i - 1] = matrix_partition(input_matrix_B, dim1 / 2, dim2 / 2, i);
    }

    // Enter recursion
    calculate_intermediates(partitioned_matrices_A, partitioned_matrices_B);
    
}
