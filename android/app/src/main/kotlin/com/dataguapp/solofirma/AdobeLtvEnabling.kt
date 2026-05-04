package com.dataguapp.solofirma

import com.itextpdf.kernel.pdf.PdfDocument
import com.itextpdf.signatures.CrlClientOnline
import com.itextpdf.signatures.LtvVerification
import com.itextpdf.signatures.OcspClientBouncyCastle
import com.itextpdf.signatures.SignatureUtil
import java.io.IOException
import java.security.GeneralSecurityException

/**
 * AdobeLtvEnabling - Adds LTV information to make PDFs "LTV enabled" as reported by Adobe Acrobat.
 * 
 * Uses iText 7's built-in LtvVerification to construct the DSS and VRI dictionaries 
 * natively according to Adobe specifications, avoiding Acrobat freezing issues.
 */
class AdobeLtvEnabling(private val pdfDocument: PdfDocument) {
    
    private val ocspClient = OcspClientBouncyCastle(null)
    private val crlClient = CrlClientOnline()
    
    /**
     * Enables LTV for all signatures in the document by using native LtvVerification
     */
    @Throws(IOException::class, GeneralSecurityException::class)
    fun enable() {
        val ltvVerification = LtvVerification(pdfDocument)
        val signatureUtil = SignatureUtil(pdfDocument)
        val signatureNames = signatureUtil.signatureNames
        
        var hasRevocationData = false

        for (signatureName in signatureNames) {
            println("INFO: Processing signature for LTV Verification: $signatureName")
            
            try {
                // Determine if we can fetch OCSP/CRL and embed them in DSS
                val isAdded = ltvVerification.addVerification(
                    signatureName, 
                    ocspClient, 
                    crlClient, 
                    LtvVerification.CertificateOption.WHOLE_CHAIN, 
                    LtvVerification.Level.OCSP_CRL, 
                    LtvVerification.CertificateInclusion.YES
                )

                if (isAdded) {
                    println("INFO: LTV verification added for $signatureName")
                    hasRevocationData = true
                } else {
                    println("WARNING: LTV verification could not be fully added for $signatureName")
                }
            } catch (e: Exception) {
                println("ERROR: Failed to add LTV for $signatureName: ${e.message}")
            }
        }
        
        if (!hasRevocationData) {
            throw Exception("No revocation data (OCSP/CRL) could be fetched for LTV verification!")
        }
        
        // Merge the LTV data into the document
        ltvVerification.merge()
        println("INFO: LTV verification merged into document")
    }
}
