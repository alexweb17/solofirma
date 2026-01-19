import sys
import os
from pathlib import Path

try:
    from PyPDF2 import PdfReader
    from PyPDF2.errors import PdfReadError
except ImportError:
    print("ERROR: PyPDF2 no esta instalado.")
    print("Instalalo con: pip install PyPDF2")
    sys.exit(1)

# Set stdout to handle utf-8
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

def analizar_pdf(ruta_pdf):
    """Analiza un PDF y retorna informacion detallada"""
    print(f"\n{'='*60}")
    print(f"Analizando: {os.path.basename(ruta_pdf)}")
    print(f"{'='*60}")
    
    info = {
        'ruta': ruta_pdf,
        'nombre': os.path.basename(ruta_pdf),
        'tamano': 0,
        'paginas': 0,
        'metadata': {},
        'objetos': 0,
        'tiene_firma': False,
        'campos_acroform': [],
        'streams_comprimidos': 0,
        'errores': []
    }
    
    try:
        # Informacion del archivo
        info['tamano'] = os.path.getsize(ruta_pdf)
        print(f"Tamano: {info['tamano']:,} bytes ({info['tamano']/1024:.2f} KB)")
        
        # Leer PDF
        reader = PdfReader(ruta_pdf)
        info['paginas'] = len(reader.pages)
        print(f"Paginas: {info['paginas']}")
        
        # Metadata
        if reader.metadata:
            info['metadata'] = dict(reader.metadata)
            print(f"\nMetadata:")
            for key, value in info['metadata'].items():
                print(f"  {key}: {value}")
        
        # Contar objetos
        if hasattr(reader, 'trailer') and reader.trailer:
            trailer = reader.trailer
            if '/Size' in trailer:
                info['objetos'] = trailer['/Size']
                print(f"\nNumero de objetos: {info['objetos']}")
        
        # Buscar AcroForm (formularios y firmas)
        root = reader.trailer.get('/Root')
        if hasattr(root, 'get_object'):
            root = root.get_object()
            
        if root and '/AcroForm' in root:
            print(f"\n[OK] Contiene AcroForm (formularios/firmas)")
            info['tiene_firma'] = True
            
            acroform = root['/AcroForm']
            if hasattr(acroform, 'get_object'):
                acroform = acroform.get_object()
                
            if '/Fields' in acroform:
                fields = acroform['/Fields']
                print(f"  Numero de campos: {len(fields)}")
                
                # Analizar campos
                for i, field in enumerate(fields):
                    field_obj = field.get_object() if hasattr(field, 'get_object') else field
                    if '/T' in field_obj:
                        field_name = field_obj['/T']
                        field_type = field_obj.get('/FT', 'Unknown')
                        print(f"  Campo {i+1}: {field_name} (Tipo: {field_type})")
                        info['campos_acroform'].append({
                            'nombre': str(field_name),
                            'tipo': str(field_type)
                        })
                        
                        # Verificar si es firma digital
                        if '/V' in field_obj:
                            v_obj = field_obj['/V']
                            if hasattr(v_obj, 'get_object'):
                                v_obj = v_obj.get_object()
                            if '/Type' in v_obj and v_obj['/Type'] == '/Sig':
                                print(f"    -> FIRMA DIGITAL DETECTADA")
                                print(f"    SubFilter: {v_obj.get('/SubFilter', 'N/A')}")
                                print(f"    Filter: {v_obj.get('/Filter', 'N/A')}")
                                if '/Contents' in v_obj:
                                    print(f"    Tamano firma: {len(v_obj['/Contents'])} bytes")
                                if '/ByteRange' in v_obj:
                                    print(f"    ByteRange: {v_obj['/ByteRange']}")
        
        # Analizar streams comprimidos
        for page_num, page in enumerate(reader.pages):
            if '/Contents' in page:
                contents = page['/Contents']
                if hasattr(contents, 'get_object'):
                    contents = contents.get_object()
                if isinstance(contents, list):
                    for content in contents:
                        if hasattr(content, 'get_object'):
                            content_obj = content.get_object()
                            if '/Filter' in content_obj:
                                info['streams_comprimidos'] += 1
                elif '/Filter' in contents:
                    info['streams_comprimidos'] += 1
        
        if info['streams_comprimidos'] > 0:
            print(f"\nStreams comprimidos: {info['streams_comprimidos']}")
        
        # Verificar cifrado
        if reader.is_encrypted:
            print(f"\n[!] PDF CIFRADO")
            info['errores'].append("PDF cifrado")
        
        print(f"\n[OK] Analisis completado sin errores criticos")
        
    except PdfReadError as e:
        error_msg = f"Error al leer PDF: {str(e)}"
        print(f"\n[X] {error_msg}")
        info['errores'].append(error_msg)
    except Exception as e:
        error_msg = f"Error inesperado: {str(e)}"
        print(f"\n[X] {error_msg}")
        info['errores'].append(error_msg)
    
    return info

def comparar_pdfs(info1, info2):
    """Compara dos PDFs y muestra diferencias"""
    print(f"\n{'='*60}")
    print("COMPARACION")
    print(f"{'='*60}")
    
    print(f"\n1. TAMANO:")
    print(f"  {info1['nombre']}: {info1['tamano']:,} bytes")
    print(f"  {info2['nombre']}: {info2['tamano']:,} bytes")
    diff_tamano = info1['tamano'] - info2['tamano']
    print(f"  Diferencia: {abs(diff_tamano):,} bytes ({'mas grande' if diff_tamano > 0 else 'mas pequeno'})")
    
    print(f"\n2. OBJETOS:")
    print(f"  {info1['nombre']}: {info1['objetos']} objetos")
    print(f"  {info2['nombre']}: {info2['objetos']} objetos")
    if info1['objetos'] != info2['objetos']:
        print(f"  [!] DIFERENCIA: {abs(info1['objetos'] - info2['objetos'])} objetos de diferencia")
    
    print(f"\n3. FIRMAS:")
    print(f"  {info1['nombre']}: {len(info1['campos_acroform'])} campos")
    print(f"  {info2['nombre']}: {len(info2['campos_acroform'])} campos")
    
    print(f"\n4. COMPRESION:")
    print(f"  {info1['nombre']}: {info1['streams_comprimidos']} streams comprimidos")
    print(f"  {info2['nombre']}: {info2['streams_comprimidos']} streams comprimidos")
    
    print(f"\n5. ERRORES:")
    print(f"  {info1['nombre']}: {len(info1['errores'])} errores")
    if info1['errores']:
        for error in info1['errores']:
            print(f"    - {error}")
    print(f"  {info2['nombre']}: {len(info2['errores'])} errores")
    if info2['errores']:
        for error in info2['errores']:
            print(f"    - {error}")
    
    # Conclusiones
    print(f"\n{'='*60}")
    print("CONCLUSIONES:")
    print(f"{'='*60}")
    
    if info1['errores'] and not info2['errores']:
        print(f"\n[!] {info1['nombre']} tiene errores de lectura que {info2['nombre']} no tiene.")
        print("  Esto podria causar que Adobe se congele al intentar procesarlo.")
    
    if info1['objetos'] != info2['objetos']:
        print(f"\n[!] Diferencia en numero de objetos puede indicar:")
        print("  - Diferentes metodos de firma")
        print("  - Informacion adicional embebida")
        print("  - Posible corrupcion")
    
    if info1['tamano'] < info2['tamano'] and info1['streams_comprimidos'] > info2['streams_comprimidos']:
        print(f"\n[!] {info1['nombre']} usa mas compresion.")
        print("  Adobe Reader podria tener problemas con algoritmos de compresion agresivos.")

if __name__ == "__main__":
    # Rutas de los PDFs
    pdf1 = "No Abre - firmado con solofirma.pdf"
    pdf2 = "Si abre - firmado con firmaec.pdf"
    
    print("ANALIZADOR DE PDFs FIRMADOS")
    print("=" * 60)
    
    # Verificar que existen los archivos
    if not os.path.exists(pdf1):
        print(f"[X] No se encuentra: {pdf1}")
        print(f"   Asegurate de ejecutar el script en la carpeta correcta")
        sys.exit(1)
    
    if not os.path.exists(pdf2):
        print(f"[X] No se encuentra: {pdf2}")
        print(f"   Asegurate de ejecutar el script en la carpeta correcta")
        sys.exit(1)
    
    # Redirigir stdout a archivo
    with open('report.txt', 'w', encoding='utf-8') as f:
        original_stdout = sys.stdout
        sys.stdout = f
        
        try:
            # Analizar ambos PDFs
            info1 = analizar_pdf(pdf1)
            info2 = analizar_pdf(pdf2)
            
            # Comparar
            comparar_pdfs(info1, info2)
            
            print(f"\n{'='*60}")
            print("Analisis completado")
            print(f"{'='*60}")
        finally:
            sys.stdout = original_stdout
            
    # Imprimir confirmación en consola real
    print("Reporte generado en report.txt")