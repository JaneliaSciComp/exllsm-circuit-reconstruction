#!/usr/bin/env python

import argparse
import csv
import os
import time
import pandas as pd


def main():

    parser = argparse.ArgumentParser(
        description='Aggregate U-NET post-processing results')

    parser.add_argument('-i', '--input_csvs_path', dest='input_csvs_dir',
                        type=str, required=True, help='Path to the input csvs')

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
        csv_files = [csv_file for csv_file in os.listdir(input_csvs_dir)
                     if os.path.isfile(os.path.join(input_csvs_dir, csv_file))]
        df_from_each_file = (pd.read_csv(f, sep=',') for f in csv_files)
        df_merged = pd.concat(df_from_each_file, ignore_index=True)
        df_merged.to_csv(output_csv_file)

    elapsed_time = time.time() - start_time
    print(f"DONE! Total running time was {elapsed_time:0.4f} seconds")


if __name__ == "__main__":
    main()
