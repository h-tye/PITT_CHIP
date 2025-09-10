#include "main.h"

/**
 * CODING STANDARDS:
 * 1. Avoid using complex libraries 
 * 2. Arrays should be used instead of pointers where possible
 * 3. Structs are okay but should not have associated functions, i.e no methods
*/


int main(int dim1, int dim2) {

    // Define input array structure, temporaray until I/O implemented
    int *input_buffer = (int *)malloc(dim1 * dim2 * sizeof(int));

    Matrix input_matrix = matrix_partition(input_buffer, dim1, dim2);

}

