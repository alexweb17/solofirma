import sys
import os

try:
    from PyPDF2 import PdfReader
except ImportError:
    print("Installing PyPDF2...")
    os.system("pip install PyPDF2")
    from PyPDF2 import PdfReader

def extract_dss_info(pdf_path):
    """Extract DSS (Document Security Store) information from a PDF"""
    print(f"\n{'='*70}")
    print(f"DEEP ANALYSIS: {os.path.basename(pdf_path)}")
    print(f"{'='*70}")
    
    try:
        reader = PdfReader(pdf_path)
        
        # Get the root object
        root = reader.trailer.get('/Root')
        if hasattr(root, 'get_object'):
            root = root.get_object()
        
        dss_status = "[MISSING]"
        dss_details = ""
        
        # Check for DSS (Document Security Store)
        if '/DSS' in root:
            dss_status = "[FOUND]"
            dss = root['/DSS']
            if hasattr(dss, 'get_object'):
                dss = dss.get_object()
            
            # Helper to count array items
            def count_items(d, key):
                if key in d:
                    obj = d[key]
                    if hasattr(obj, 'get_object'):
                        obj = obj.get_object()
                    if isinstance(obj, list):
                        return len(obj)
                return 0

            n_certs = count_items(dss, '/Certs')
            n_ocsps = count_items(dss, '/OCSPs')
            n_crls = count_items(dss, '/CRLs')
            
            dss_details = f"Certs:{n_certs}, OCSPs:{n_ocsps}, CRLs:{n_crls}"
        
        print(f"FINAL_REPORT: DSS {dss_status} - {dss_details}")

        
        # Check for AcroForm and signatures
        if '/AcroForm' in root:
            acroform = root['/AcroForm']
            if hasattr(acroform, 'get_object'):
                acroform = acroform.get_object()
            
            if '/Fields' in acroform:
                fields = acroform['/Fields']
                print(f"\nSignature fields: {len(fields)}")
                
                for i, field in enumerate(fields):
                    field_obj = field.get_object() if hasattr(field, 'get_object') else field
                    if '/V' in field_obj:
                        sig_dict = field_obj['/V']
                        if hasattr(sig_dict, 'get_object'):
                            sig_dict = sig_dict.get_object()
                        
                        contents = sig_dict.get('/Contents', b'')
                        print(f"  Signature {i+1} size: {len(contents)} bytes")
                        
                        if '/SubFilter' in sig_dict:
                            print(f"  SubFilter: {sig_dict['/SubFilter']}")
                        
    except Exception as e:
        print(f"Error analyzing PDF: {e}")

if __name__ == "__main__":
    # Redirect stdout to handle encoding if needed, though print should work
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except:
        pass
    
    solo_firma = "No Abre - firmado con solofirma.pdf"
    
    if os.path.exists(solo_firma):
        extract_dss_info(solo_firma)
    else:
        print(f"File not found: {solo_firma}")

