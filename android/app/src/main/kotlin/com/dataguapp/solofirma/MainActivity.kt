package com.dataguapp.solofirma

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.KeyStore
import java.security.PrivateKey
import java.security.cert.Certificate
import java.security.cert.X509Certificate
import com.itextpdf.kernel.pdf.PdfReader
import com.itextpdf.kernel.pdf.PdfWriter
import com.itextpdf.kernel.pdf.StampingProperties
import com.itextpdf.signatures.PdfSigner
import com.itextpdf.signatures.PrivateKeySignature
import com.itextpdf.signatures.BouncyCastleDigest
import com.itextpdf.signatures.IExternalDigest
import com.itextpdf.signatures.IExternalSignature
import com.itextpdf.signatures.DigestAlgorithms
import com.itextpdf.signatures.PdfSignatureAppearance
import com.itextpdf.kernel.geom.Rectangle
import com.itextpdf.signatures.TSAClientBouncyCastle
import com.itextpdf.signatures.OcspClientBouncyCastle
import com.itextpdf.signatures.CrlClientOnline
import org.bouncycastle.jce.provider.BouncyCastleProvider
import java.security.Security

class MainActivity: FlutterActivity() {
    private val FILES_CHANNEL = "com.dataguapp.solofirma/files"
    private val SIGNING_CHANNEL = "com.dataguapp.solofirma/signing"

    init {
        // Register BouncyCastle provider
        // Android has a built-in "BC" provider that is incomplete/deprecated.
        // We must remove it to ensure our full BouncyCastle (bcprov-jdk15on) is used.
        try {
            Security.removeProvider("BC")
        } catch (e: Exception) {
            // Ignore if it wasn't there
        }
        Security.addProvider(BouncyCastleProvider())
        
        // Fix for Android XML parser issue "This parser does not support specification..."
        // Register our custom safe factory early
        try {
            com.itextpdf.kernel.utils.XmlProcessorCreator.setXmlParserFactory(SafeXmlParserFactory())
            println("INFO: SafeXmlParserFactory registered in init")
        } catch (e: Exception) {
            println("ERROR: Failed to register SafeXmlParserFactory: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Files channel (existing)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                        result.success(null)
                    } else {
                        result.error("INVALID_PATH", "Path cannot be null", null)
                    }
                }
                "saveToDownloads" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val fileName = call.argument<String>("fileName")
                    if (sourcePath != null && fileName != null) {
                        try {
                            val savedPath = saveFileToDownloads(sourcePath, fileName)
                            if (savedPath != null) {
                                result.success(savedPath)
                            } else {
                                result.error("SAVE_FAILED", "Failed to save file", null)
                            }
                        } catch (e: Exception) {
                            result.error("SAVE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "sourcePath and fileName are required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Signing channel (new)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIGNING_CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "signPdfWithLtv" -> {
                    Thread {
                        try {
                            val pdfPath = call.argument<String>("pdfPath")!!
                            val p12Bytes = call.argument<ByteArray>("p12Bytes")!!
                            val password = call.argument<String>("password")!!
                            val outputPath = call.argument<String>("outputPath")!!
                            val signerName = call.argument<String>("signerName") ?: "Firmado digitalmente"
                            val reason = call.argument<String>("reason") ?: "Documento firmado con SoloFirma"
                            val location = call.argument<String>("location") ?: "Ecuador"
                            val pageNumber = call.argument<Int>("pageNumber") ?: 1
                            val x = call.argument<Double>("x")?.toFloat() ?: 100f
                            val y = call.argument<Double>("y")?.toFloat() ?: 100f
                            val width = call.argument<Double>("width")?.toFloat() ?: 200f
                            val height = call.argument<Double>("height")?.toFloat() ?: 50f
                            
                            val signedPath = signPdfWithIText(
                                pdfPath, p12Bytes, password, outputPath,
                                signerName, reason, location,
                                pageNumber, x, y, width, height
                            )
                            
                            runOnUiThread {
                                result.success(signedPath)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                            runOnUiThread {
                                result.error("SIGNING_ERROR", e.message, e.stackTraceToString())
                            }
                        }
                    }.start()
                }
                "enableLtv" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        Thread {
                            try {
                                val reader = PdfReader(path)
                                val writer = PdfWriter(path + ".ltv.tmp")
                                val pdfDoc = com.itextpdf.kernel.pdf.PdfDocument(reader, writer, StampingProperties().useAppendMode())
                                
                                val adobeLtv = AdobeLtvEnabling(pdfDoc)
                                adobeLtv.enable()
                                
                                pdfDoc.close()
                                
                                val originalFile = File(path)
                                val tempFile = File(path + ".ltv.tmp")
                                
                                if (originalFile.delete()) {
                                    if (tempFile.renameTo(originalFile)) {
                                        runOnUiThread {
                                            result.success(path)
                                        }
                                    } else {
                                        runOnUiThread {
                                            result.error("LTV_ERROR", "Could not rename temp file", null)
                                        }
                                    }
                                } else {
                                    runOnUiThread {
                                        result.error("LTV_ERROR", "Could not delete original file", null)
                                    }
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                                runOnUiThread {
                                    result.error("LTV_ERROR", e.message, e.stackTraceToString())
                                }
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun signPdfWithIText(
        pdfPath: String,
        p12Bytes: ByteArray,
        password: String,
        outputPath: String,
        signerName: String,
        reason: String,
        location: String,
        pageNumber: Int,
        x: Float, y: Float, width: Float, height: Float
    ): String {
        // Load P12/PFX keystore
        val keyStore = KeyStore.getInstance("PKCS12")
        keyStore.load(p12Bytes.inputStream(), password.toCharArray())
        
        // Get private key and certificate chain
        // Get private key and certificate chain
        val aliases = keyStore.aliases()
        var alias: String? = null
        var privateKey: PrivateKey? = null
        
        while (aliases.hasMoreElements()) {
            val currentAlias = aliases.nextElement()
            if (keyStore.isKeyEntry(currentAlias)) {
                try {
                    val key = keyStore.getKey(currentAlias, password.toCharArray())
                    if (key is PrivateKey) {
                        alias = currentAlias
                        privateKey = key
                        break
                    }
                } catch (e: Exception) {
                    println("DEBUG: Failed to get key for alias $currentAlias: ${e.message}")
                }
            }
        }
        
        if (alias == null || privateKey == null) {
            throw Exception("No valid private key found in P12 file. Password might be incorrect or file format issue.")
        }
        
        val chain = keyStore.getCertificateChain(alias)
        if (chain == null || chain.isEmpty()) {
             throw Exception("No certificate chain found for alias $alias")
        }
        
        // Create PDF reader and signer
        val reader = PdfReader(pdfPath)
        val outputFile = File(outputPath)
        val signer = PdfSigner(reader, FileOutputStream(outputFile), StampingProperties().useAppendMode())
        
        // Configure signature appearance
        val appearance = signer.signatureAppearance
        appearance.setReason(reason)
        appearance.setLocation(location)
        appearance.setPageNumber(pageNumber)
        appearance.setPageRect(Rectangle(x, y, width, height))
        appearance.setLayer2Text("$signerName\n${java.text.SimpleDateFormat("dd/MM/yyyy HH:mm:ss").format(java.util.Date())}")
        
        signer.fieldName = "SoloFirmaSignature_${System.currentTimeMillis()}"
        
        // Create signature components
        val digest: IExternalDigest = BouncyCastleDigest()
        val signature: IExternalSignature = PrivateKeySignature(privateKey, DigestAlgorithms.SHA256, BouncyCastleProvider.PROVIDER_NAME)
        
        // TSA Client (Timestamp Authority)
        val tsaClient = TSAClientBouncyCastle("http://timestamp.digicert.com")
        
        // OCSP and CRL clients - used ONLY in the DSS post-signing step (NOT inline)
        // Embedding CRL/OCSP inline causes "Not enough space" because CRLs can be megabytes.
        val ocspClient = OcspClientBouncyCastle(null)
        val crlClient = CrlClientOnline()
        
        // Sign with CMS (PKCS7) for Adobe Reader compatibility
        // CRL/OCSP are NOT included inline - they go in the DSS (step 2)
        signer.signDetached(
            digest,
            signature,
            chain,
            null,        // NO inline CRL (will be added via DSS)
            null,        // NO inline OCSP (will be added via DSS)
            tsaClient,
            0,
            PdfSigner.CryptoStandard.CMS
        )
        
        // STEP 2: Add DSS (Document Security Store) with LTV information
        // This adds CRL/OCSP OUTSIDE the signature container, in append mode
        try {
            addDssLtvInfo(outputPath, ocspClient, crlClient)
            println("INFO: DSS LTV information added successfully")
        } catch (e: Exception) {
            println("WARN: Could not add DSS LTV info: ${e.message}")
            // Don't throw - the signature itself is valid, LTV is optional enhancement
        }
        
        return outputPath
    }
    
    /**
     * Adds Document Security Store (DSS) with LTV information to an already-signed PDF.
     * Uses AdobeLtvEnabling class which builds DSS manually for Adobe compatibility.
     */
    private fun addDssLtvInfo(
        pdfPath: String,
        ocspClient: OcspClientBouncyCastle,
        crlClient: CrlClientOnline
    ) {
        val tempPath = pdfPath + ".ltv.tmp"
        
        // Re-open the signed PDF in append mode
        val reader = PdfReader(pdfPath)
        val writer = PdfWriter(tempPath)
        val pdfDoc = com.itextpdf.kernel.pdf.PdfDocument(reader, writer, StampingProperties().useAppendMode())
        
        try {
            // Use AdobeLtvEnabling to add DSS with certificates, OCSP, and CRL
            val adobeLtv = AdobeLtvEnabling(pdfDoc)
            adobeLtv.enable()
            
            pdfDoc.close()
            
            // Replace original with LTV-enabled version
            val originalFile = File(pdfPath)
            val tempFile = File(tempPath)
            originalFile.delete()
            tempFile.renameTo(originalFile)
            
            println("INFO: AdobeLtvEnabling completed successfully")
        } catch (e: Exception) {
            pdfDoc.close()
            File(tempPath).delete()
            throw e
        }
    }

    private fun saveFileToDownloads(sourcePath: String, fileName: String): String? {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            throw Exception("Source file does not exist")
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/SoloFirma")
            }

            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create MediaStore entry")

            resolver.openOutputStream(uri)?.use { outputStream ->
                FileInputStream(sourceFile).use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            }

            MediaScannerConnection.scanFile(this, arrayOf(uri.path), null, null)
            "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/SoloFirma/$fileName"
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val solofirmaDir = File(downloadsDir, "SoloFirma")
            if (!solofirmaDir.exists()) {
                solofirmaDir.mkdirs()
            }
            val destFile = File(solofirmaDir, fileName)
            sourceFile.copyTo(destFile, overwrite = true)
            MediaScannerConnection.scanFile(this, arrayOf(destFile.absolutePath), null, null)
            destFile.absolutePath
        }
    }
}
