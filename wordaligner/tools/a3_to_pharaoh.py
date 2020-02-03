import sys
import math

def get_seqnum(line):
    return int(line.split(")")[0].split("(")[1])

def get_score(line):
    return float(line.split()[-1])

def get_source(line):
    tokens = []
    for i in line.split(" }) "):
        tokens.append(i.split()[0])
    return " ".join(tokens[1:])

def get_pharaoh(line):
    alignment = []
    index = 0
    for i in line.split(" }) ")[:-1]:
        q = i.split(" ({ ")
        if len(q) >= 2:
            for j in q[1].split():
                p1 = int(index) - 1
                p2 = int(j) - 1
                if p1 >= 0 and p2 >= 0:
                    alignment.append("{}-{}".format(p1, p2))
        index += 1
    return " ".join(alignment)
    
for i in sys.stdin:
    line2 = sys.stdin.readline().strip()
    line3 = sys.stdin.readline().strip()
    trg   = line2
    src   = get_source(line3)
    pha   = get_pharaoh(line3)
    seq   = get_seqnum(i)
    score = math.log(get_score(i))
    print("{}\t{}\t{}\t{}\t{}".format(seq, pha, src, trg, score))
    