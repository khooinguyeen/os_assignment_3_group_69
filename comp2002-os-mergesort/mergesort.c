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

	while (i <= leftend) B[k++] = A[i++];

	while (j <= rightend) B[k++] = A[j++];

	memcpy(&A[leftstart], &B[leftstart], (rightend - leftstart + 1) * sizeof(int));
}

/* this function will be called by parallel_mergesort() as its base case. */
void my_mergesort(int left, int right){
	if (left < right) {
		int mid = left + (right - left) / 2;

		my_mergesort(left, mid);
		my_mergesort(mid + 1, right);

		merge(left, mid, mid + 1, right);
	}
}

/* this function will be called by the testing program. */
void * parallel_mergesort(void *arg){
	struct argument *a = (struct argument*) arg;
	int left = a->left;
	int right = a->right;
	int level = a->level;

	if (left >= right) {
		if (level > 0) free(arg);
		return NULL; 
	}

	if (level >= cutoff) {
		my_mergesort(left, right);
		if (level > 0) free(arg);
		return NULL;
	}

	int mid = left + (right - left) / 2;
	struct argument *left_arg = buildArgs(left, mid, level + 1);
	struct argument *right_arg = buildArgs(mid + 1, right, level + 1);

	if (left_arg == NULL || right_arg == NULL) {
		free(left_arg);
		free(right_arg);
		my_mergesort(left, right);
		if (level > 0) free(arg);
		return NULL;
	}

	pthread_t thread_left, thread_right;
	int left_flag = 0, right_flag = 0;
	left_flag = pthread_create(&thread_left, NULL, parallel_mergesort, left_arg);

	if (left_flag != 0) {
		perror("Fail to create left thread");
		fprintf(stderr, "Error: fail to create left thread with left %d, right %d, level %d!\n", left, mid, level+1);
		free(left_arg);
		free(right_arg);
		my_mergesort(left, right);

		if (level > 0) free(arg);
		return NULL;
	}

	right_flag = pthread_create(&thread_right, NULL, parallel_mergesort, right_arg);

	if (right_flag != 0) {
		perror("Fail to create right thread");
		fprintf(stderr, "Error: fail to create right thread with left %d, right %d, level %d!\n", mid+1, right, level+1);
		free(right_arg);

		pthread_join(thread_left, NULL);

		my_mergesort(mid+1, right);

		merge(left, mid, mid+1, right);

		if (level > 0) free(arg);
		return NULL;
	}


	pthread_join(thread_left, NULL);
	pthread_join(thread_right, NULL);

	merge(left, mid, mid + 1, right);

	if (level > 0) free(arg);
	return NULL;
}

/* we build the argument for the parallel_mergesort function. */
struct argument * buildArgs(int left, int right, int level){
	struct argument * arg = malloc(sizeof(struct argument));

	/* check malloc safety, mark fail if can not generate arg */
	if (arg == NULL) {
		perror("Fail to allocate argument");
		fprintf(stderr, "Error: malloc for arg with left %d, right %d, level %d failed!\n", left, right, level);
		return NULL;
	}

	arg->left = left;
	arg->right = right;
	arg->level = level;

	return arg;
}

