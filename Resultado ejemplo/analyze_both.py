import sys
import os
sys.stdout.reconfigure(encoding='utf-8')
from PyPDF2 import PdfReader

pdfs = ['No Abre - firmado con solofirma.pdf', 'Si abre - firmado con firmaec.pdf']

output = []

for pdf_name in pdfs:
    output.append(f'\n{"="*70}')
    output.append(f'ANALISIS: {pdf_name}')
    output.append(f'{"="*70}')
    reader = PdfReader(pdf_name)
    root = reader.trailer.get('/Root')
    if hasattr(root, 'get_object'):
        root = root.get_object()
    
    # Check DSS
    if '/DSS' in root:
        dss = root['/DSS']
        if hasattr(dss, 'get_object'):
            dss = dss.get_object()
        output.append(f'DSS: ENCONTRADO')
        output.append(f'  Claves DSS: {list(dss.keys())}')
        for key in ['/Certs', '/OCSPs', '/CRLs', '/VRI']:
            if key in dss:
                obj = dss[key]
                if hasattr(obj, 'get_object'):
                    obj = obj.get_object()
                if isinstance(obj, list):
                    output.append(f'  {key}: {len(obj)} elementos')
                    # Show sizes of each element
                    for idx, elem in enumerate(obj):
                        if hasattr(elem, 'get_object'):
                            elem = elem.get_object()
                        if hasattr(elem, 'get_data'):
                            data = elem.get_data()
                            output.append(f'    [{idx}]: {len(data)} bytes')
                elif isinstance(obj, dict):
                    output.append(f'  {key}: diccionario con claves {list(obj.keys())}')
                else:
                    output.append(f'  {key}: tipo={type(obj).__name__}')
    else:
        output.append(f'DSS: NO ENCONTRADO')
    
    # Check AcroForm
    if '/AcroForm' in root:
        acroform = root['/AcroForm']
        if hasattr(acroform, 'get_object'):
            acroform = acroform.get_object()
        output.append(f'AcroForm: ENCONTRADO')
        output.append(f'  Claves: {list(acroform.keys())}')
        if '/Fields' in acroform:
            fields = acroform['/Fields']
            if hasattr(fields, 'get_object'):
                fields = fields.get_object()
            output.append(f'  Fields: {len(fields)}')
            for i, field in enumerate(fields):
                if hasattr(field, 'get_object'):
                    field = field.get_object()
                ft = field.get('/FT', 'N/A')
                t = field.get('/T', 'N/A')
                output.append(f'    Field {i}: FT={ft}, T={t}')
                if '/V' in field:
                    v = field['/V']
                    if hasattr(v, 'get_object'):
                        v = v.get_object()
                    sf = v.get('/SubFilter', 'N/A')
                    filt = v.get('/Filter', 'N/A')
                    contents = v.get('/Contents', b'')
                    output.append(f'      SubFilter: {sf}')
                    output.append(f'      Filter: {filt}')
                    output.append(f'      Contents size: {len(contents)} bytes')
                    # Check all keys
                    output.append(f'      Sig dict keys: {list(v.keys())}')
    else:
        output.append(f'AcroForm: NO ENCONTRADO')
    
    # Claves raiz
    output.append(f'Claves raiz del catalogo: {list(root.keys())}')

with open('analysis_output.txt', 'w', encoding='utf-8') as f:
    f.write('\n'.join(output))

print('Analysis written to analysis_output.txt')
