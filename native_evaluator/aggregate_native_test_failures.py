#!/usr/bin/env python3
import os
import subprocess
import json

def is_test_executable(filename):
    return (
        filename.endswith('_test')
        and os.path.isfile(filename)
        and os.access(filename, os.X_OK)
    )

def find_test_executables(directory):
    return [
        os.path.join(directory, f)
        for f in os.listdir(directory)
        if is_test_executable(os.path.join(directory, f))
    ]

def run_test_and_collect_failures(test_path):
    try:
        result = subprocess.run(
            [test_path, '--json'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=60
        )
        output = result.stdout.strip()
        if not output:
            return []
        data = json.loads(output)
        failures = []
        # Try common keys for failures
        for test_case in data.get('tests', []):
            if not test_case.get('success', True):
                failures.append({
                    'file': test_case.get('file', 'unknown'),
                    'line': test_case.get('line', 'unknown'),
                    'message': test_case.get('message', test_case.get('name', ''))
                })
        return failures
    except Exception as e:
        return [{'file': test_path, 'line': '-', 'message': f'Error running/parsing: {e}'}]

def main():
    test_dir = os.path.dirname(os.path.abspath(__file__))
    test_bins = find_test_executables(test_dir)
    all_failures = {}
    for test_bin in test_bins:
        failures = run_test_and_collect_failures(test_bin)
        if failures:
            all_failures[os.path.basename(test_bin)] = failures

    if not all_failures:
        print("All tests passed (no failures detected).")
        return

    print("Aggregated Test Failures:")
    for test_bin, failures in all_failures.items():
        print(f"\n{test_bin}:")
        for fail in failures:
            print(f"  {fail['file']}:{fail['line']} - {fail['message']}")

if __name__ == '__main__':
    main()