from argparse import ArgumentParser
import sys
import random

def main():
    parser = ArgumentParser()
    parser.add_argument('-p', '--probability', type=float, default=0.1, help="Probability of each sentence to be ommited")
    parser.add_argument('-s', '--seed', type=int, help="Random seed")
    args = parser.parse_args(sys.argv[1:])

    if args.seed is not None:
        random.seed(args.seed)

    for line in sys.stdin:
        if random.random() <= args.probability:
            continue
        sys.stdout.write(line)

if __name__ == "__main__":
    main()
