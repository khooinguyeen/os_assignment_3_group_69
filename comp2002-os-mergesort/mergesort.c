/**
 * This file implements parallel mergesort.
 */

#include <stdio.h>
#include <string.h> /* for memcpy */
#include <stdlib.h> /* for malloc */
#include "mergesort.h"

/* this function will be called by mergesort() and also by parallel_mergesort(). */
void merge(int leftstart, int leftend, int rightstart, int rightend){
	int i = leftstart, j = rightstart, k = leftstart;

	// add each number from sorted subarrays to array b
	while (i <= leftend && j <= rightend) {
		if (A[i] <= A[j]) {
			B[k] = A[i];
			i++;
		} else {
			B[k] = A[j];
			j++;
		}
		k++;
	}

	// add the leftover numbers from one of the subarrays
	// one subarrays will be fully added while the other still have leftover numbers
	while (i <= leftend) B[k++] = A[i++];

	while (j <= rightend) B[k++] = A[j++];

	// copy sorted array b to a
	memcpy(&A[leftstart], &B[leftstart], (rightend - leftstart + 1) * sizeof(int));
}

/* this function will be called by parallel_mergesort() as its base case. */
void my_mergesort(int left, int right){
	// no sort if left and right index cross
	if (left < right) {
		int mid = left + (right - left) / 2;

		// merge sort left and right subarrays
		my_mergesort(left, mid);
		my_mergesort(mid + 1, right);
		// merge both sorted subarrays
		merge(left, mid, mid + 1, right);
	}
}

/* this function will be called by the testing program. */
void * parallel_mergesort(void *arg){

	struct argument *a = (struct argument*) arg;
	int left = a->left;
	int right = a->right;
	int level = a->level;

	// no sort if left and right index cross
	if (left >= right) {
		if (level > 0) free(arg);
		return NULL; 
	}

	// only sparse threads if not meet cut off level yet
	if (level >= cutoff) {
		my_mergesort(left, right);
		if (level > 0) free(arg);
		return NULL;
	}

	// split subarrays for multithreading
	int mid = left + (right - left) / 2;
	// create arguments for both left and right threads
	struct argument *left_arg = buildArgs(left, mid, level + 1);
	struct argument *right_arg = buildArgs(mid + 1, right, level + 1);

	pthread_t thread_left, thread_right;
	// return flags for thread create
	int left_flag = 0, right_flag = 0;
	left_flag = pthread_create(&thread_left, NULL, parallel_mergesort, left_arg);
	// handle left thread failure
	// exit if fail to create
	if (left_flag != 0) {
		fprintf(stderr, "Error: fail to create left thread with left %d, right %d, level %d!\n", left, mid, level+1);
		exit(EXIT_FAILURE);
	}

	right_flag = pthread_create(&thread_right, NULL, parallel_mergesort, right_arg);
	// handle right thread failure
	// exit if fail to create
	if (right_flag != 0) {
		fprintf(stderr, "Error: fail to create right thread with left %d, right %d, level %d!\n", mid+1, right, level+1);
		exit(EXIT_FAILURE);
	}

	// safely join threads after execution
	pthread_join(thread_left, NULL);
	pthread_join(thread_right, NULL);

	merge(left, mid, mid + 1, right);

	// only free if not level 0 argument
	// each thread free its own arg
	if (level > 0) free(arg);
	return NULL;
}

/* we build the argument for the parallel_mergesort function. */
struct argument * buildArgs(int left, int right, int level){
	struct argument * arg = malloc(sizeof(struct argument));

	// check malloc safely, mark fail if can not generate argument
	if (arg == NULL) {
		perror("Fail to allocate argument");
		fprintf(stderr, "Error: malloc for arg with left %d, right %d, level %d failed!\n", left, right, level);
		exit(EXIT_FAILURE);
	}

	arg->left = left;
	arg->right = right;
	arg->level = level;

	return arg;
}

