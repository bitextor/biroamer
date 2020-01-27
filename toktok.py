import nltk
import sys
    
try:
    nltk.data.find('misc/perluniprops')
except:
    nltk.download('perluniprops')

try:
    nltk.data.find('corpora/nonbreaking_prefixes')
except:
    nltk.download('nonbreaking_prefixes')

from nltk.tokenize.toktok import ToktokTokenizer

tokenizer = ToktokTokenizer()

for i in sys.stdin:
    tokens = " ".join(tokenizer.tokenize(i.strip()))
    sys.stdout.write(f"{tokens}\n")
