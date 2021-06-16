"""Build tmx from tab separated file
Usage:
  buildtmx.py LANG1 LANG2 

"""

from docopt import docopt
from xml.sax.saxutils import escape
import sys
import datetime

tmx_header = """<?xml version="1.0"?>
<tmx version="1.4">
 <header
   adminlang="en"
   srclang="{}"
   o-tmf="PlainText"
   creationtool="buildtmx"
   creationtoolversion="4.0"
   datatype="PlainText"
   segtype="sentence"
   creationdate="{}"
   o-encoding="utf-8">
 </header>
 <body>
"""
 
 
tmx_footer ="  </body>\n</tmx>\n"

tu_template="""    <tu>
      <tuv xml:lang="{}">
        <seg>{}</seg>
      </tuv>
      <tuv xml:lang="{}">
        <seg>{}</seg>
      </tuv>
    </tu>
"""
      
      
def fix_tu(sentence):
    output = []
    parts = sentence.split("<entity>")
    output.append(escape(parts[0]))
    for i in parts[1:]:
        subparts = i.split("</entity>")
        output.append(escape(subparts[0])+"</hi>"+escape(subparts[1]))

    return "<hi>".join(output)

def print_tu(lang1, lang2, s1, s2):
    global tu_template    
    return tu_template.format(lang1, fix_tu(s1), lang2, fix_tu(s2))

def main(arguments):
    global tmx_header, tmx_footer
    
    input = sys.stdin
    output = sys.stdout
    
    lang1 = arguments["LANG1"]
    lang2 = arguments["LANG2"]
    
    creationdate = datetime.datetime.now().strftime("%Y%m%dT%H%M%S")
    
    output.write(tmx_header.format("en", creationdate))
    
    for i in input:
        sentences = i.strip().split("\t")
        output.write(print_tu(lang1, lang2, sentences[0], sentences[1]))
    
    output.write(tmx_footer)
    output.close()

def args_and_main():
    arguments = docopt(__doc__, version='buildtmx 1.0')
    main(arguments)

if __name__ == '__main__':
    args_and_main()

