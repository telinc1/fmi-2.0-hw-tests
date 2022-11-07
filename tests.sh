#!/bin/bash

test_dir=$1

if [ ! -d "$test_dir" ]; then
	echo "\"$1\" is not a test directory." >&2	
	exit 100
fi

if ! mkdir test-results; then
	echo "\"test-results\" directory cannot be created." >&2
	exit 101
fi

tasks="$(find "$test_dir" -mindepth 1 -maxdepth 1 -not -name '.*' -type d -printf '%f\n' | sort)"

errors=0
report="test-results/report.txt"
echo -n "Tests ran on: " >> $report
date >> $report
echo >> $report

for task in $tasks; do
	results="test-results/$task.txt"

	echo -n "Tests ran on: " >> $results
	date >> $results
	echo >> $results

	correct_tests=0
	echo "Compiler output:" >> $results
	g++ fn*_d1_$task.cpp -o "$task.out" -std=c++14 -Wpedantic &>> $results

	if [ $? -eq 0 ]; then
		echo >> $results
		echo "Compilation OK." >> $results
		echo >> $results
		echo >> $results

		tests_count=$(($(find "$test_dir/$task" | wc -l) / 2))

		for test in $(seq 1 $tests_count); do
			temp_file="$(mktemp)"
			timeout 3 "./$task.out" < "$test_dir/$task/${test}-in" &> "$temp_file"

			if diff -Z "$temp_file" "$test_dir/$task/${test}-out" > /dev/null; then
				echo "Test \"${test}\": OK" >> $results
				correct_tests=$((correct_tests+1))
			else
				echo "Test \"${test}\": Failed" >> $results

				echo "Input:" >> $results
				cat "$test_dir/$task/${test}-in" >> $results
				echo >> $results

				echo "Expected:" >> $results
				cat "$test_dir/$task/${test}-out" >> $results
				echo >> $results

				echo "Actual:" >> $results
				head -c 1000 "$temp_file" >> $results
				echo >> $results

				errors=$((errors+1))
			fi

			echo "____________________" >> $results
			echo >> $results
		done

		percentage="$(awk -v correct=$correct_tests -v total=$tests_count 'BEGIN{printf("%.2f", correct * 100 / total)}')"
		points="$(awk -v cent=$percentage 'BEGIN{printf("%.1f", cent / 100 * 2.5)}')"

		echo "Grade: ${correct_tests}/${tests_count}, ${percentage}%, $points pts." >> $results
		echo "Task ${task}: ${correct_tests}/${tests_count}, ${percentage}%, $points pts." >> $report
	else
		errors=$((errors+1))

		echo >> $results
		echo "Compilation failed. Skipping tests." >> $results
		echo "Task ${task}: Does not compile" >> $report
	fi
done




exit $errors
