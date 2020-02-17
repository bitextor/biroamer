import csv
import os
import re
import sys


l1 = sys.argv[1]
l2 = sys.argv[2]
workdir = sys.argv[3]

if not os.path.exists(workdir+"/../output"):
    os.makedirs(workdir+"/../output")

# Basenames
filenames  = [os.path.basename(i) for i in sys.argv[4:]]

# Full paths
ofnames    = [workdir+"/../output/"+re.sub(".{}-{}$".format(l1,l2), "", i)+".aligned" for i in filenames]
filenames  = [workdir+"/"+i for i in filenames]
retainfile = workdir + "/TOTAL.retained"
tokenfile1 = workdir + "/TOTAL.clean.{}".format(l1)
tokenfile2 = workdir + "/TOTAL.clean.{}".format(l2)
ali12file  = workdir + "/TOTAL.{}-{}.symali".format(l1,l2)
ali21file  = workdir + "/TOTAL.{}-{}.symali".format(l2,l1)
aliscore12 = workdir + "/TOTAL.{}-{}.aliscore".format(l1,l2)
aliscore21 = workdir + "/TOTAL.{}-{}.aliscore".format(l2,l1)

# Data files
fretain = open(retainfile, "rt")
ftok1   = open(tokenfile1, "rt")
ftok2   = open(tokenfile2, "rt")
fali12  = open(ali12file, "rt")
fali21  = open(ali21file, "rt")
fsco12  = open(aliscore12, "rt")
fsco21  = open(aliscore21, "rt")

nline = 0
nretain = 0
header = [l1, l2, "tok1", "tok2", "ali12", "ali21", "score12", "score21"]

for nfile in range(len(filenames)):
    with open(filenames[nfile], "rt") as finput, \
         open(ofnames[nfile], "wt") as foutput:
        outwriter = csv.writer(foutput, dialect=csv.excel, delimiter='\t')
        outwriter.writerow(header)
        for line in finput:
            nline += 1
            
            # The following (and tricky) two conditions filter out 'dirty' (not clean)
            # rows by printing just the lines when nline == nretain
            # keep in mind than nretain > nline-1 *always*
            # ------------------------------------------------------------------
            # if nline == nretain -> print the row
            # if nline <  nretain -> skip the row
            # if nline >  nretain -> get the next retain line, which necessarily
            #                        will be equal to nline, then therefore
            #                        print the row
            # ------------------------------------------------------------------
            
            if nline > nretain:
                nretain = int(next(fretain).strip())        
            if nline < nretain:
                continue
            
            assert(nline == nretain)
            
            row = line.strip().split("\t")
            row.append(next(ftok1).strip())
            row.append(next(ftok2).strip())
            row.append(next(fali12).strip())
            row.append(next(fali21).strip())
            nfs12 = next(fsco12).strip().split("\t")
            a = nfs12[1] if len(nfs12) > 1 else ""
            row.append(a)
            nfs21 = next(fsco21).strip().split("\t")
            a = nfs21[1] if len(nfs21) > 1 else ""
            row.append(a)
            outwriter.writerow(row)

fretain.close()
ftok1.close()
ftok2.close()
fali12.close()
fali21.close()
fsco12.close()
fsco21.close()
