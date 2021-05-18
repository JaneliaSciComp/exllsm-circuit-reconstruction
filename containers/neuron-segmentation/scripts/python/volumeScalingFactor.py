""" 
This script calculates the scaling factor of a given volume
"""
import argparse


def main():
    parser = argparse.ArgumentParser(description='Volume scaling factor')

    parser.add_argument('-i', '--input',
                        dest='input_path', type=str, required=True,
                        help='Path to the input n5')

    parser.add_argument('-d', '--data_set',
                        dest='input_data_set', type=str, default="/s0",
                        help='Path to input data set (default "/s0")')

    args = parser.parse_args()


if __name__ == "__main__":
    main()
