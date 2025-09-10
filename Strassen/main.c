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
    int *input_buffer = (int *)malloc(dim1 * dim2 * sizeof(int));

    Matrix input_matrix = matrix_build(input_buffer, dim1, dim2);

    Matrix partitioned_matrices[4]; // First 4 partitions of the matrix

    for (int i = 1; i <= 4; i++)
    {
        partitioned_matrices[i - 1] = matrix_partition(input_matrix, dim1 / 2, dim2 / 2, i);
    }

    Matrix intermediates[7]; // Intermediate matrices for Strassen's algorithm, M values

    // Enter recursion
    calculate_intermediates(partitioned_matrices, intermediates);
}
