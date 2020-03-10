import spacy
import sys
import string
from bisect import bisect
import re

PUNCTUATION = "[¡¿" + string.punctuation.replace("'","").replace("-","") + "]"
nlp = spacy.load("en_core_web_sm")

# Regular expression for emails
# https://www.regextester.com/19
email_regex = r"(\b|^)([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)(\b|$)"
# Regular expression for phone numbers
phone_regex = r"\(?(\+)?[\+\-\–\d]+[\(\)' '\+\-\–\d]{6,}\d\b"
# Regular expressions for IP addresses
# https://www.oreilly.com/library/view/regular-expressions-cookbook/9780596802837/ch07s16.html
# https://www.regextester.com/25
IPv4_regex = r"((?:[0-9]{1,3}\.){3}[0-9]{1,3})"
IPv6_regex = r"(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"

all_regex = re.compile(r"(" + email_regex + r")|(" + phone_regex + r")|(" + IPv4_regex + r")|(" + IPv6_regex + r")")

def include_nonaligned(word_alignment, meta_part):
    """Heuristic to add to the alignment intermediate words that are likely
    to be taken into account in the result"""

    if len(word_alignment) == 0:
        return word_alignment

    additions = []
    my_range = range(min(word_alignment), max(word_alignment)+1)
    for i in my_range:
        if i not in meta_part:
            additions.append(i)

    result = set(additions + list(word_alignment))

    if len(result) > len(my_range) / 2:
        return result
    else:
        return word_alignment

def color_segments(segment, points, opentag="<entity>", closetag="</entity>"):
    """Put <entity> tags inside the segment according to alignment points."""

    result = []
    offset = 0
    open_i = 0
    close_i = 0
    i = 0
    while i < len(segment):
        if close_i < len(points) and offset == points[close_i][1] and open_i != close_i:
            result.append(closetag)
            close_i += 1
            continue
        elif open_i < len(points) and points[open_i][0] == offset and not segment[i] == " ":
            result.append(opentag)
            open_i += 1
        result.append(segment[i])
        if segment[i] != " ":
            offset += 1
        i += 1

    if open_i != close_i:
        result.append(closetag)

    return "".join(result)

def trim(source_indexes, source_tokens, target_indexes, target_tokens):
    """Trim unwanted punctuation in the edges of highlighted segments when it
    is not present in the original segments."""
    global PUNCTUATION

    for i in source_indexes:
        if re.search(PUNCTUATION, source_tokens[i]):
            return target_indexes

    while len(target_indexes) > 0 and min(target_indexes) < len(target_tokens) and re.search(PUNCTUATION, target_tokens[min(target_indexes)]):
        target_indexes.remove(min(target_indexes))

    while len(target_indexes) > 0 and max(target_indexes) < len(target_tokens) and re.search(PUNCTUATION, target_tokens[max(target_indexes)]):
        target_indexes.remove(max(target_indexes))

    return target_indexes

def alignment_as_sets(ali_str):
    """Convert alignment Pharaoh-style format to a list of sets, so that the
    n-th position in the list is aligned with tokens in the set, which can be
    empty."""

    ali = [[int(parts[0]), int(parts[1])] for parts in (i.split("-") for i in ali_str.split())]
    result = [set([]) for i in range(max([j[0] for j in ali])+1)]
    for i, j in ali:
        result[i].add(j)
    return result

def offsets(tokens):
    """Calculate starting positions of each token not taking into account
    whitespaces by processing the token list and accumulating total length
    of tokens."""

    offsets = []
    pos = 0
    for i in tokens:
        offsets.append(pos)
        pos += len(i)
    return offsets

def search_offsets(highlighted, opentag="<entity>", closetag="</entity>"):
    """Calculate character positions of highlighted segments in a string not
    taking into account whitespaces."""

    pos = 0
    offsets = []
    for i in highlighted.split(opentag):
        parts = i.split(closetag)
        if len(parts) == 1:
            if i.endswith(closetag):
                offsets.append(pos)
                positem=pos
                for j in parts[0].split(" ")[:-1]:
                    positem += len(j)
                    offsets.append(positem)
            pos += len(parts[0].replace(" ", ""))
        else:
            offsets.append(pos)
            positem = pos
            for j in parts[0].split(" ")[:-1]:
                positem += len(j)
                offsets.append(positem)
            pos += len(parts[0].replace(" ", ""))
            pos += len(parts[1].replace(" ", ""))
    return offsets

def condense(search_off, src_off):
    """Calculate cluster of words by searching to independize data tokenization
    from application tokenization."""

    last = -1
    results = []
    for i in search_off:
        p = bisect(src_off, i)
        if p < 0:
            p =-(p+2)
        if p <= last:
            results[-1].add(p-1)
        else:
            results.append(set([]))
            results[-1].add(p-1)
        last = p+1
    return results


def align_loop(src_tok, trg_tok, src_ali, trg_ali, clusters):
    """For each cluster source, finds the segment in target matching best the
    source regarding the positions, including the intermediate positions when
    needed for continuity and removing possible punctuation in the edges when
    is not part of the cluster in the source. At the end, all positions are
    returned as a single set."""

    src_ali_s  = alignment_as_sets(src_ali)
    trg_ali_s  = alignment_as_sets(trg_ali)

    match_t = []
    for s in clusters:
        setlist = [src_ali_s[i] if len(src_ali_s) > i else set() for i in s]
        if len(setlist) == 0:
            continue
        w_na  = include_nonaligned(set.union(*setlist), trg_ali_s)
        clean = trim(s, src_tok, w_na, trg_tok)
        match_t.append(clean)

    return set.union(*map(set, match_t)) if len(match_t) > 0 else set()

def continuous_highlighting(sent, opentag="<entity>", closetag="</entity>"):
    """Removes gaps in the highlighting by merging consecutive or
    near-consecutive highlighted segments."""

    expression = "([<][/]{}[>])([ ]*[-/]?[ ]*)([<]{}[>])".format(closetag[2:-1], opentag[1:-1])
    return re.sub(expression, "\g<2>", sent)

def clean_tags(sent, opentag="<entity>", closetag="</entity>"):
    """Removes highlight marks of the sentence."""

    return sent.replace(opentag, "").replace(closetag, "")

def get_alignment_points(offsets, tokens, words):
    """Calculate the alignment points based on corresponding words, offsets and
    token lengths."""
    
    return [[offsets[i], offsets[i]+len(tokens[i])] for i in sorted(words) if i < len(offsets)]


def align(src, trg, src_tok, trg_tok, src_ali, trg_ali):
    """Highlights with '<entity>' in 'trg' the segment that best matches with the
    highlighted segment 'src' and the tokenization and alignment information.
    Returns the original segment modified to make the highlighting continuous,
    the target segment with the matching part highlighted and a boolean"""

    # Split lists
    src_tok_list = src_tok.split()
    trg_tok_list = trg_tok.split()

    # Forward
    clusters  = condense(search_offsets(src), offsets(src_tok_list))
    words     = align_loop(src_tok_list, trg_tok_list, src_ali, trg_ali, clusters)
    trg_off   = offsets(trg_tok_list)
    points    = get_alignment_points(trg_off, trg_tok_list, words)
    new_trg   = color_segments(trg, points)

    cont_new_trg = continuous_highlighting(new_trg)

    return src, cont_new_trg

def reverse_alignment(alignment):
    """ Reverse the symmetric alingment, putting it in the proper order."""
    
    points = [(int(i.split("-")[1]),int(i.split("-")[0])) for i in alignment.split(" ")]
    points_s = sorted(points, key=lambda tup: (tup[0], tup[1]))
    return " ".join([f"{i[0]}-{i[1]}" for i in points_s])    
    
def get_entities(sentence):
    """ Obtain the entities that spacy detect or match any regex and append the entity tags """

    global nlp
    entities = list(nlp(sentence).ents) + list(all_regex.finditer(sentence))
    # sort the objects by their (start, end) positions in sentence
    entities.sort(key=lambda x: x.span() if type(x) is re.Match else (x.start_char, x.end_char))

    fragments = []
    cur = 0

    for ent in entities:
        if type(ent) is re.Match:
            start = ent.span()[0]
            end = ent.span()[1]
        else:
            if ent.label_ not in {"PERSON", "FAC", "ORG", "PRODUCT", "GPE", "LOC"}:
                continue
            start = ent.start_char
            end = ent.end_char

        if start < cur: # If two match overlap skip the second one
            continue

        fragments.append(sentence[cur:start])
        fragments.append(f'<entity>')
        fragments.append(sentence[start:end])
        fragments.append('</entity>')
        cur = end

    fragments.append(sentence[cur:])
    
    return "".join(fragments)

def main():
    for i in sys.stdin:
        fields = i.strip().split("\t")
        if len(fields) < 5:
            sys.stderr.write('Error with line: '+ str(fields))
            continue
        outent = get_entities(fields[0])
        outsrc, outtrg = align(outent, fields[1], fields[2], fields[3], fields[4], reverse_alignment(fields[4]))
        sys.stdout.write(f"{outsrc}\t{outtrg}\n")


if __name__ == "__main__":
    main()
