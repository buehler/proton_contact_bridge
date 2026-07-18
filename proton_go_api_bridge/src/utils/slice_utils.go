package utils

import "iter"

func MapSlice[T any, U any](input []T, mapper func(T) U) []U {
	result := make([]U, len(input))
	for i, v := range input {
		result[i] = mapper(v)
	}
	return result
}

func WhereSlice[T any](input []T, predicate func(T) bool) []T {
	result := make([]T, 0, len(input))
	for _, v := range input {
		if predicate(v) {
			result = append(result, v)
		}
	}
	return result
}

func MapIter[T any, U any](input iter.Seq[T], mapper func(T) U) iter.Seq[U] {
	return func(yield func(U) bool) {
		for value := range input {
			if !yield(mapper(value)) {
				return
			}
		}
	}
}
