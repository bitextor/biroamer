import sys
import csv


fields = sys.argv[1:]

tabin = csv.reader(sys.stdin, dialect=csv.excel)
header = next(tabin)
dic = {header[i]:i for i in range(len(header))}

assert(all(i in dic for i in fields))

for row in tabin:
    outputrow = [row[dic[i]] for i in fields]
    sys.stdout.write("\t".join(outputrow))
    sys.stdout.write("\n")
