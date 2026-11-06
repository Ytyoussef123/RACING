import sys
def scan(src):
    depth = 0; i = 0; n = len(src); line = 1; prev = ''; marks = []
    while i < n:
        c = src[i]
        if c == '\n': line += 1; i += 1; continue
        if src.startswith('//', i): j = src.find('\n', i); i = n if j < 0 else j; continue
        if src.startswith('/*', i): j = src.find('*/', i); line += src[i:j].count('\n'); i = j + 2; continue
        if c in '"\'`':
            q = c; i += 1
            while i < n and src[i] != q:
                if src[i] == '\\': i += 2; continue
                if src[i] == '\n': line += 1
                i += 1
            i += 1; prev = 'x'; continue
        if c == '/' and prev in '(,=:[!&|?{};':
            i += 1
            while i < n and src[i] != '/':
                if src[i] == '\\': i += 2; continue
                i += 1
            i += 1
            while i < n and src[i].isalpha(): i += 1
            prev = 'x'; continue
        if c == '{': depth += 1; marks.append(line)
        elif c == '}': depth -= 1; marks and marks.pop()
        if not c.isspace(): prev = c if c in '(,=:[!&|?{};' else 'x'
        i += 1
    return depth, marks
for f in sys.argv[1:]:
    d, m = scan(open(f).read()); print(f, 'depth', d, 'unclosed opened at lines', m[-6:])
