package com.dataguapp.solofirma

import com.itextpdf.kernel.pdf.*
import com.itextpdf.signatures.*
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.cert.X509Certificate

/**
 * AdobeLtvEnabling - Adds LTV information to make PDFs "LTV enabled" as reported by Adobe Acrobat.
 * 
 * This is a simplified version that adds DSS with certificates, OCSP responses, and CRLs
 * fetched at signing time. The goal is to avoid Adobe Reader needing to fetch these online.
 */
class AdobeLtvEnabling(private val pdfDocument: PdfDocument) {
    
    private val ocspClient = OcspClientBouncyCastle(null)
    private val crlClient = CrlClientOnline()
    
    /**
     * Enables LTV for all signatures in the document by adding DSS dictionary
     */
    @Throws(IOException::class, GeneralSecurityException::class)
    fun enable() {
        val signatureUtil = SignatureUtil(pdfDocument)
        val signatureNames = signatureUtil.signatureNames
        
        val allCerts = mutableListOf<ByteArray>()
        val allOcsps = mutableListOf<ByteArray>()
        val allCrls = mutableListOf<ByteArray>()
        
        for (signatureName in signatureNames) {
            println("INFO: Processing signature: $signatureName")
            val pkcs7 = signatureUtil.readSignatureData(signatureName)
            
            // Get certificates from signature
            val certs = pkcs7.signCertificateChain
            println("INFO: Found ${certs.size} certificates in chain")
            
            // For each certificate in chain, get OCSP/CRL
            for (i in 0 until certs.size) {
                val cert = certs[i] as? X509Certificate ?: continue
                
                // Add certificate
                allCerts.add(cert.encoded)
                
                // Try to get issuer for OCSP/CRL
                val issuer = if (i + 1 < certs.size) certs[i + 1] as? X509Certificate else null
                
                if (issuer != null) {
                    // Get OCSP response
                    println("INFO: Fetching OCSP for ${cert.subjectDN}")
                    try {
                        val ocspResp = ocspClient.getEncoded(cert, issuer, null)
                        if (ocspResp != null) {
                            allOcsps.add(ocspResp)
                            println("INFO: Added OCSP for ${cert.subjectDN}")
                        } else {
                            println("WARNING: OCSP response was null for ${cert.subjectDN}")
                        }
                    } catch (e: Exception) {
                        println("ERROR: OCSP fetch failed: ${e.message}")
                        // Don't throw for individual OCSP failure, but track it?
                        // For now, let's throw if ALL fail.
                    }
                    
                    // Get CRLs
                    try {
                        println("INFO: Fetching CRL for ${cert.subjectDN}")
                        val crls = crlClient.getEncoded(cert, null)
                        if (crls != null) {
                            for (crl in crls) {
                                allCrls.add(crl)
                                println("INFO: Added CRL for ${cert.subjectDN}")
                            }
                        }
                    } catch (e: Exception) {
                        println("ERROR: CRL fetch failed: ${e.message}")
                    }
                }
            }
        }
        
        // Build and add DSS dictionary to the catalog
        if (allOcsps.isEmpty() && allCrls.isEmpty()) {
             throw Exception("No revocation data (OCSP/CRL) could be fetched! Check internet connection or certificate validity.")
        }
        
        addDssToCatalog(allCerts, allOcsps, allCrls)
    }
    
    private fun addDssToCatalog(
        certs: List<ByteArray>,
        ocsps: List<ByteArray>,
        crls: List<ByteArray>
    ) {
        val catalog = pdfDocument.catalog
        
        val dss = PdfDictionary()
        
        // Add Certs array
        if (certs.isNotEmpty()) {
            val certsArray = PdfArray()
            for (certBytes in certs) {
                val stream = PdfStream(certBytes)
                certsArray.add(stream.makeIndirect(pdfDocument))
            }
            dss.put(PdfName.Certs, certsArray)
        }
        
        // Add OCSPs array
        if (ocsps.isNotEmpty()) {
            val ocspsArray = PdfArray()
            for (ocspBytes in ocsps) {
                val stream = PdfStream(ocspBytes)
                ocspsArray.add(stream.makeIndirect(pdfDocument))
            }
            dss.put(PdfName.OCSPs, ocspsArray)
        }
        
        // Add CRLs array
        if (crls.isNotEmpty()) {
            val crlsArray = PdfArray()
            for (crlBytes in crls) {
                val stream = PdfStream(crlBytes)
                crlsArray.add(stream.makeIndirect(pdfDocument))
            }
            dss.put(PdfName.CRLs, crlsArray)
        }
        
        // Add DSS to catalog
        catalog.put(PdfName("DSS"), dss.makeIndirect(pdfDocument))
        
        println("INFO: DSS added with ${certs.size} certs, ${ocsps.size} OCSPs, ${crls.size} CRLs")
    }
}
