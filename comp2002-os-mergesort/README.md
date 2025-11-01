## OS Assignment 3: Concurrency - Parallel Merge Sort

* Authors: 
  * Khoi Nguyen Mai - a1902103
  * Do Phong Tran - a1873825
  * Gia Khanh Nguyen - a1898379
* Group name: OS Group 69 

## Overview

This program implements a parallel merge sort algorithm using the C `pthread` library. The implementation recursively divides an array into 2 subarrays and creates threads to sort both halves concurrently, up to the cutoff level specified in user input. Once the cutoff is reached, the algorithm switches to traditional single-threaded merge sort. The program also measures execution time to help demonstrate the performance improvement achieved through parallel execution compared to sequential sorting.

## Manifest

* **[mergesort.c](comp2002-os-mergesort/mergesort.c)** - Implementation of parallel merge sort with the following functions:
  * `merge()` - Merges two sorted subarrays into one sorted array 
  * `my_mergesort()` - Traditional single-threaded merge sort used when cutoff is reached
  * `parallel_mergesort()` - Multi-threaded merge sort that creates child threads to sort subarrays in parallel
  * `buildArgs()` - Helper function that constructs argument structs
* **[mergesort.h](comp2002-os-mergesort/mergesort.h)** - Header file containing function prototypes, struct definitions, and global variable declarations
* **[test-mergesort.c](comp2002-os-mergesort/test-mergesort.c)** - Testing program that can generate random arrays and measures sorting time
* **[Makefile](comp2002-os-mergesort/Makefile)** - Build configuration for compiling the project
* **[README.md](comp2002-os-mergesort/README.md)** - Project documentation (this file)

## Building the project

First, change your directory to `comp2002-os-mergesort`:
```bash
cd comp2002-os-mergesort
```

If you use Windows, remember to uncomment line 7 in **[test-mergesort.c](comp2002-os-mergesort/test-mergesort.c)**:
```c
#include <error.h>     /* On MacOS you won't need this line */
```

To compile the project, run:
```bash
make
```

This generates the executable `test-mergesort`.

Then, to run the program:
```bash
./test-mergesort <input size> <cutoff level> <seed> 
```

**Parameters:**
* `input_size`: Number of elements in the array 
* `cutoff_level`: Maximum number of thread levels (0 = serial sort, higher values = more parallelism)
* `seed`: Random seed for array generation

**Example:**
```bash
./test-mergesort 100000000 7 1234
```

To clean build environment:
```bash
make clean
```

## Features and usage

**Main Features:**
1. **Serial Merge Sort** (`my_mergesort`): Classic recursive merge sort implementation serving as the base case for parallel merge sort
2. **Parallel Merge Sort** (`parallel_mergesort`): Multi-threaded implementation using pthreads that creates child threads until reaching the specified cutoff level
3. **Efficient Merging** (`merge`): Combines two sorted subarrays using a temporary array with O(n) time complexity
4. **Performance Measurement**: Reports execution time to evaluate speedup from parallelisation

**Usage Examples:**

Test serial sort (no threads):
```bash
./test-mergesort 1000 0 1234
```

Test parallel sort with 1 level (2 threads):
```bash
./test-mergesort 1000 1 1234
```

Performance test with large array:
```bash
./test-mergesort 100000000 3 1234
```

## Testing

This section should detail how you tested your code. Simply stating "I ran
it a few times and it seems to work" is not sufficient. Your testing needs
to be detailed here.

## Known Bugs

Currently, there are no known bugs or errors in the code. The implementation handles all test cases correctly including edge cases with small arrays, large cutoff values, and various array sizes.

**Limitation (not a bug)**: If the cutoff level is set extremely high, the program may exit if the system cannot create the required number of threads. The number of threads created is $2^{current~level}$, so a cutoff of 20 would attempt to create over 1 million threads, which exceeds typical system limits. This is not a code bug but rather a system resource constraint. Users should set appropriate cutoff values based on their system's capabilities (cutoff ≤ 10 is safe for most systems).


## Reflection and Self Assessment

Discuss the issues you encountered during development and testing. What
problems did you have? What did you have to research and learn on your own?
What kinds of errors did you get? How did you fix them?

What parts of the project did you find challenging? Is there anything that
finally "clicked" for you in the process of working on this project? How well
did the development and testing process go for you?


### Understanding Thread Ownership and Memory Management: 
This was the most significant challenge. Initially, we thought we had to free left_arg and right_arg after creating child threads. However, this was fundamentally wrong because:
 - If we freed them before pthread_join(), the child threads would access freed memory (use-after-free bug)
 - If we freed them after pthread_join(), we'd have a double-free error because the child threads had already freed those arguments

Through testing and discussion, we learned the correct principle: "each thread frees the argument that was passed TO it, not the arguments it passes to others." This means:
  - The parent thread frees arg (what was given to it)
  - Child threads free left_arg and right_arg (what was given to them)

Moreover, we discovered an additional complexity: the test program (test-mergesort.c) also calls free(arg) on the initial argument after parallel_mergesort() returns. This created a potential double-free for the level-0 argument. Therefore, we only free(arg) in parallel_mergesort() when level > 0.

### Pthread API Requirements:
Understanding why parallel_mergesort() must have the signature void * function(void *arg) took some research. We learned this is mandated by pthread_create() and requires casting to use our custom struct. 
And for void * function, we have to return a NULL pointer. A first, we thought this is similar to normal void function that does not need returning.

### Base Case Handling:
Determining when to stop creating threads required careful consideration. We implemented the check if (left >= right) before the cutoff check to handle edge cases where the cutoff is larger than necessary, preventing infinite thread creation


## Sources Used

1. **Course Materials:**
   - Operating Systems: Three Easy Pieces - Chapter 26 (Concurrency: An Introduction) and Chapter 27 (Interlude: Thread API)
  
2. **Additional Resources:**
   - YouTube video: "Algorithms: Merge Sort" by HackerRank (https://youtu.be/KF2j-9iSf4Q?si=T8H4ItWBNWXBOeZl) - for understanding merge sort and the merge operation
   - GeeksforGeeks: "C Program for Merge Sort" (https://www.geeksforgeeks.org/c/c-program-for-merge-sort/) - for reference on classic merge sort implementation
