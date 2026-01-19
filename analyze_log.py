
import codecs

try:
    with codecs.open('execution.log', 'r', encoding='utf-16-le', errors='ignore') as f:
        content = f.read()
except:
    with open('execution.log', 'r', errors='ignore') as f:
        content = f.read()

# Replace carriage returns with newlines to handle progress bars
content = content.replace('\r', '\n')
lines = content.splitlines()

for i, line in enumerate(lines):
    if 'DEBUG' in line or 'ERROR' in line or 'Exception' in line:
        print(f"--- MATCH AT LINE {i} ---")
        print(repr(line))
        # Print context
        for j in range(1, 15):
             if i + j < len(lines):
                 print(f"CTX {j}: {repr(lines[i+j])}")
        print("-----------------------")
