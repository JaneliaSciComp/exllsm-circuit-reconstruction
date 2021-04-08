import sys
import getopt

from utils import hdf5_create


def main(argv):

    file_name = None
    volume_size = None

    try:
        options, remainder = getopt.getopt(
            argv, "f:s:", ["file_name=", "volume_size="])
    except getopt.GetoptError:
        print("ERROR!")
        print("Usage: create_h5.py -f <file_name> -s <comma_separated_volume_size_width,height,depth>")
        sys.exit(1)

    for opt, arg in options:
        if opt in ('-f', '--file_name'):
            file_name = arg
        elif opt in ('-s', '--volume_size'):
            volume_size = tuple(map(int, arg.split(',')))

    hdf5_create(file_name, volume_size)


if __name__ == "__main__":
    main(sys.argv[1:])
