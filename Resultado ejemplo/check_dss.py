from PyPDF2 import PdfReader
import sys

try:
    reader = PdfReader("No Abre - firmado con solofirma.pdf")
    root = reader.trailer['/Root']
    if '/DSS' in root:
        print("DSS_FOUND")
        dss = root['/DSS']
        print(f"Keys: {list(dss.keys())}")
    else:
        print("DSS_MISSING")
except Exception as e:
    print(f"ERROR: {e}")
