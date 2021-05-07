#!/usr/bin/env python

import argparse
import csv
import fnmatch
import os
import pandas as pd
import time


def main():

    parser = argparse.ArgumentParser(
        description='Aggregate U-NET post-processing results')

    parser.add_argument('-i', '--input_csvs_path', dest='input_csvs_dir',
                        type=str, required=True,
                        help='Path to the input csvs')

    parser.add_argument('-o', '--output_csv_file', dest='output_csv_file',
                        type=str, help='Path to aggregated csv file')

    args = parser.parse_args()
    input_csvs_dir = args.input_csvs_dir
    output_csv_file = (args.output_csv_file
                       if args.output_csv_file
                       else input_csvs_dir.replace('_csv', '') + '.csv')

    start_time = time.time()

    if os.path.exists(input_csvs_dir) and os.path.isdir(input_csvs_dir):
        # list all csvs
        csv_files = [os.path.join(input_csvs_dir,csv_file)
                     for csv_file in os.listdir(input_csvs_dir)
                        if os.path.isfile(os.path.join(input_csvs_dir,
                                                       csv_file))
                        and fnmatch.fnmatch(csv_file, '*.csv')]
        if len(csv_files) > 0:
            df_from_each_file = (pd.read_csv(f, sep=',') for f in csv_files)
            df_merged = pd.concat(df_from_each_file, ignore_index=True)
            df_merged.to_csv(output_csv_file)
            print('Merged', str(len(csv_files)), 'files from', input_csvs_dir,
                  'into', output_csv_file)
        else:
            print('No csv file found in', input_csvs_dir, 'so',
                  output_csv_file, 'will not be created')
    else:
        print(input_csvs_dir, 'not found so',
              output_csv_file, 'will not be created')
    elapsed_time = time.time() - start_time
    print(f"DONE! Total running time was {elapsed_time:0.4f} seconds")


if __name__ == "__main__":
    main()
