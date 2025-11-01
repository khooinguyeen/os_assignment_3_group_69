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

We automate our testing scenarios through a Bash script `auto_test.sh`, which generates a folder `auto_test_outputs` on each scenario run and saves the result of each scenario in a seperated csv file such as `integration_results.csv` or a text file `performance_summary.txt` for recording speed up result after multithreading. Raw logs of each test run is also available on the console.  

The test script `auto_test.sh` can be run by following these steps: 
- Clean all previously compiled file: `make clean`.
- Recompile all .c files: `make all`. 
- Run all test scenarios with `./auto_tests.sh all`. 
- Individual scenarios can be run following this command `./auto_tests.sh <add-scenario>` (E.g: `./auto_tests.sh integration`).

We decide to test four different scenarios for our parallel merge sort implementation, with every invocation exited with status 0 and `check_if_sorted` confirmed sorted arrays, yielding full PASS rows in .csv files.

### 1. Integration testing 
We wanted to test if all four functions in mergesort.c worked together perfectly by using two test cases: 

Command: `./auto_tests.sh integration`

- A fixed small array case (`n=5000`, `cutoff=0`, `seed=1234`)
- Randomise n in the 10 000–20 000 element range with a random cutoff (1, 3) and a random seed. 

Both executions completed without errors, verifying that argument parsing, single-threaded merge sort recursion and thread teardown succeed in a normal command line run. Results are recorded in `auto_test_outputs/integration_results.csv`.

### 2. Correctness testing 
We wanted to verify that the merge sort algorithm correctly sorted randomised arrays under different cases:

Command: `./auto_tests.sh correctness` 

- Combinations of different array sizes, seeds and cutoffs: 
  - Random small and medium array sizes (10 up to 10 000 000)
  - Different cutoffs (1-3) and seeds (69, 1234, 99999). 
- Edge cases:
  - Minimum array size of 2, with cutoff value 0,1. 
  - Cutoff of value 0: serial merge sort
  - Special arrays: sorted, descending order and an array of equal value.

All cases were run perfectly under various input parameters with `PASS`, and our code proved to be able to handle edge cases without breaking. Results are recorded in `auto_test_outputs/correctness_results.csv`.

### 3. Performance testing 
As correctness was not an issue, we expanded our test scenarios to involves huge arrays with a variety of cutoff, measuring the performance difference between serial merge sort and parallel merge sort:
Command: `./auto_tests.sh performance`

- Using fixed-size array of 100 000 000 random numbers.
- Interate cutoff value from 0 to 10. 

On our lab machine the serial baseline was ~13.4 s; every parallel run from cutoff ≥ 3 achieved a measured speedup above the 2× requirement (sometimes it was achieved with cutoff >= 2). Detailed timings are in `auto_test_outputs/performance_results.csv` with an easy-to-read summary in `auto_test_outputs/performance_summary.txt`.

### 4. Stress testing  
We also want to stress test the parallel merge sort with high cutoff value and large arrays to analyse how the algorithm behaves under continuous high volumn tests. 
Command: `./auto_tests.sh stress`

- Stress test: large array size of 100 000 000 across cutoffs 8-14 with seed 676. 
- Stable test: same array size under repeated runs at cutoff 8 with seeds from 2023 to 2026. 

All high-load runs completed and logged PASS entries to `auto_test_outputs/stress_results.csv`, providing confidence that deep recursion and repeated thread creation remain stable.

**P/s**: After each scenario we spot-checked the emitted CSV files and the console logs to ensure no FAIL rows appeared and that timing data remained numeric. Together these tests cover functional correctness, edge modes, performance objectives, and long-running stress scenarios.

## Known Bugs

Currently, there are no known bugs or errors in the code. The implementation handles all test cases correctly including edge cases with small arrays, large cutoff values, and various array sizes.

**Limitation (not a bug)**: If the cutoff level is set extremely high, the program may exit if the system cannot create the required number of threads. The number of threads created is $2^{current~level}$, so a cutoff of 20 would attempt to create over 1 million threads, which exceeds typical system limits. This is not a code bug but rather a system resource constraint. Users should set appropriate cutoff values based on their system's capabilities (cutoff ≤ 10 is safe for most systems).


## Reflection and Self Assessment
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
Determining when to stop creating threads required careful consideration. We implemented the check if (left >= right) before the cutoff check to handle edge cases where the cutoff is larger than necessary, preventing infinite thread creation.

### Resource Limits:
While investigating how the algorithm behaves under extream conditions, we tried to test the program with n over 100 000 000 and pushing cutoff over 14. These resulted in multiple system failures, especially in thread creation. This was expected as parallel merge sort an enourmous array size like 100 000 000 result in large number of spawn threads, which overstrained our local machines. Same issue with high cutoff value like 15 allowed 2^16 - 1 threads to flow during execution, causing flaky behavior and most of the time thread creation failure. 

### Performance Plateau:
We tried to analyse if higher number of threads equal to faster speed, which was proved to not be the case when cutoff value went beyond 10. Performance started to improved very slowly after cutoff value hitting 5, and basically freezed after hiting 8. No improvements are seen after these, and interestingly, the performance got worse once the cutoff value passed 10. We came to the conclusion that too many threads can cause hugh overhead, and only a fixed amount of threads can run at the same time. In simple term, it was the huge delay queue of threads that slows down the system. 

### Conclusion
Overall, our team learened a lot on how to apply multithreading into improving performance of a suitable algorithm, such as merge sort. The process of debugging our implementation strengthen our understanding of controlling thread resources, preventing memory leaks or double free issue. At the same time, writing test cases forced us to think of potential cases that our code could go wrong, but also gave us confident that our code could run under multiple conditions, while knowing the existing constraint that came with limited hardware resources on our local machines. 

## Sources Used

1. **Course Materials:**
   - Operating Systems: Three Easy Pieces - Chapter 26 (Concurrency: An Introduction) and Chapter 27 (Interlude: Thread API)
  
2. **Additional Resources:**
   - YouTube video: "Algorithms: Merge Sort" by HackerRank (https://youtu.be/KF2j-9iSf4Q?si=T8H4ItWBNWXBOeZl) - for understanding merge sort and the merge operation
   - GeeksforGeeks: "C Program for Merge Sort" (https://www.geeksforgeeks.org/c/c-program-for-merge-sort/) - for reference on classic merge sort implementation
