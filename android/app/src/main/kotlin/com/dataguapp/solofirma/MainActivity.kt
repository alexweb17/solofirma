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
import java.security.cert.CertificateFactory
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
import com.itextpdf.io.image.ImageDataFactory
import com.itextpdf.signatures.TSAClientBouncyCastle
import com.itextpdf.signatures.OcspClientBouncyCastle
import com.itextpdf.signatures.CrlClientOnline
import org.bouncycastle.jce.provider.BouncyCastleProvider
import java.security.Security

class MainActivity : FlutterActivity() {

    private val FILES_CHANNEL = "com.dataguapp.solofirma/files"
    private val SIGNING_CHANNEL = "com.dataguapp.solofirma/signing"

    init {
        // Registrar BouncyCastle como provider principal.
        // Android tiene un "BC" interno incompleto/obsoleto; hay que reemplazarlo.
        try {
            Security.removeProvider("BC")
        } catch (e: Exception) { /* ignorar si no existía */ }
        Security.addProvider(BouncyCastleProvider())

        // Fix para el parser XML de iText en Android
        try {
            com.itextpdf.kernel.utils.XmlProcessorCreator.setXmlParserFactory(SafeXmlParserFactory())
            println("INFO: SafeXmlParserFactory registrado")
        } catch (e: Exception) {
            println("ERROR: No se pudo registrar SafeXmlParserFactory: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal de archivos
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL).setMethodCallHandler { call, result ->
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

        // Canal de firma
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIGNING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "signPdfWithLtv" -> {
                    Thread {
                        try {
                            val pdfPath     = call.argument<String>("pdfPath")!!
                            val p12Bytes    = call.argument<ByteArray>("p12Bytes")!!
                            val password    = call.argument<String>("password")!!
                            val outputPath  = call.argument<String>("outputPath")!!
                            val signerName  = call.argument<String>("signerName") ?: "Firmado digitalmente"
                            val reason      = call.argument<String>("reason")     ?: "Documento firmado con SoloFirma"
                            val location    = call.argument<String>("location")   ?: "Ecuador"
                            val pageNumber  = call.argument<Int>("pageNumber")    ?: 1
                            val x           = call.argument<Double>("x")?.toFloat()      ?: 100f
                            val y           = call.argument<Double>("y")?.toFloat()      ?: 100f
                            val width       = call.argument<Double>("width")?.toFloat()  ?: 200f
                            val height      = call.argument<Double>("height")?.toFloat() ?: 50f

                            val qrBytes = call.argument<ByteArray>("qrBytes")

                            val signedPath = signPdfWithIText(
                                pdfPath, p12Bytes, password, outputPath,
                                signerName, reason, location,
                                pageNumber, x, y, width, height, qrBytes
                            )
                            runOnUiThread { result.success(signedPath) }
                        } catch (e: Exception) {
                            e.printStackTrace()
                            runOnUiThread { result.error("SIGNING_ERROR", e.message, e.stackTraceToString()) }
                        }
                    }.start()
                }
                "enableLtv" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        Thread {
                            try {
                                val reader  = PdfReader(path)
                                val writer  = PdfWriter(path + ".ltv.tmp")
                                val pdfDoc  = com.itextpdf.kernel.pdf.PdfDocument(
                                    reader, writer, StampingProperties().useAppendMode()
                                )
                                AdobeLtvEnabling(pdfDoc).enable()
                                pdfDoc.close()

                                // Atomic rename: backup → rename → cleanup
                                val originalFile = File(path)
                                val tempFile     = File(path + ".ltv.tmp")
                                val backupFile   = File(path + ".bak")

                                originalFile.renameTo(backupFile)
                                if (tempFile.renameTo(originalFile)) {
                                    backupFile.delete()
                                    runOnUiThread { result.success(path) }
                                } else {
                                    // Rollback: restaurar backup
                                    backupFile.renameTo(originalFile)
                                    tempFile.delete()
                                    runOnUiThread {
                                        result.error("LTV_ERROR", "Atomic rename failed — original restaurado desde backup", null)
                                    }
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                                runOnUiThread { result.error("LTV_ERROR", e.message, e.stackTraceToString()) }
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
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        qrBytes: ByteArray?
    ): String {

        // ── 1. Cargar el keystore P12 ──────────────────────────────────────────
        val keyStore = KeyStore.getInstance("PKCS12")
        keyStore.load(p12Bytes.inputStream(), password.toCharArray())

        // ── 2. Obtener clave privada ───────────────────────────────────────────
        var alias: String? = null
        var privateKey: PrivateKey? = null
        val aliases = keyStore.aliases()
        while (aliases.hasMoreElements()) {
            val currentAlias = aliases.nextElement()
            if (keyStore.isKeyEntry(currentAlias)) {
                try {
                    val key = keyStore.getKey(currentAlias, password.toCharArray())
                    if (key is PrivateKey) {
                        alias      = currentAlias
                        privateKey = key
                        break
                    }
                } catch (e: Exception) {
                    println("DEBUG: No se pudo obtener clave para alias $currentAlias: ${e.message}")
                }
            }
        }
        requireNotNull(privateKey) { "No se encontró clave privada en el archivo P12. Contraseña incorrecta o archivo dañado." }
        requireNotNull(alias)

        val rawChain = keyStore.getCertificateChain(alias)
        require(!rawChain.isNullOrEmpty()) { "No se encontró cadena de certificados para alias $alias" }

        // ── 3. FIX PRINCIPAL: Re-codificar certificados vía BouncyCastle ───────
        //
        // Android devuelve los certificados del KeyStore en su propio formato interno
        // (AndroidOpenSSL / sun.security.x509.X509CertImpl), que iText no puede embeber
        // correctamente dentro de la estructura CMS. Esto provoca que Adobe Acrobat
        // muestre "Desconocido" y que "Mostrar certificado de firmante" aparezca vacío.
        //
        // La solución es forzar la re-codificación de cada certificado a través del
        // CertificateFactory de BouncyCastle, garantizando instancias 100% compatibles
        // con el motor de firma de iText.
        val bcCertFactory = CertificateFactory.getInstance("X.509", BouncyCastleProvider.PROVIDER_NAME)
        val bcChain: Array<Certificate> = rawChain.map { cert ->
            bcCertFactory.generateCertificate(cert.encoded.inputStream())
        }.toTypedArray()

        // Log de diagnóstico: muestra cuántos certs hay y el CN de cada uno
        println("DEBUG: Cadena de certificados (${bcChain.size} cert(s)):")
        bcChain.forEachIndexed { i, cert ->
            if (cert is X509Certificate) {
                println("DEBUG:   [$i] Subject : ${cert.subjectDN}")
                println("DEBUG:   [$i] Issuer  : ${cert.issuerDN}")
                println("DEBUG:   [$i] Serial  : ${cert.serialNumber}")
                println("DEBUG:   [$i] Encoding: ${cert.encoded.size} bytes")
            }
        }

        // ── 4. Preparar PdfSigner con validación de página ─────────────────────
        val reader     = PdfReader(pdfPath)
        val outputFile = File(outputPath)
        val signer     = PdfSigner(reader, FileOutputStream(outputFile), StampingProperties().useAppendMode())

        // Validar que pageNumber esté dentro del rango del PDF
        val totalPages = signer.document.numberOfPages
        val validPageNumber = pageNumber.coerceIn(1, totalPages)
        if (pageNumber != validPageNumber) {
            println("WARN: pageNumber $pageNumber fuera de rango [1..$totalPages], ajustado a $validPageNumber")
        }

        // ── 5. Apariencia visual de la firma ──────────────────────────────────
        //
        // CONVERSIÓN DE COORDENADAS:
        // Flutter/Syncfusion usa origen ARRIBA-IZQUIERDA (Y crece hacia abajo).
        // PDF/iText usa origen ABAJO-IZQUIERDA (Y crece hacia arriba).
        // Fórmula: iTextY = pageHeight - flutterY - signatureHeight
        val page = signer.document.getPage(validPageNumber)
        val pageSize = page.pageSize
        val pageHeight = pageSize.height
        val pageWidth = pageSize.width

        // Convertir Y de coordenadas Flutter → coordenadas PDF
        val pdfY = pageHeight - y - height

        // Clamp X e Y para que la firma no se salga de los límites de la página
        val clampedX = x.coerceIn(0f, (pageWidth - width).coerceAtLeast(0f))
        val clampedY = pdfY.coerceIn(0f, (pageHeight - height).coerceAtLeast(0f))

        println("DEBUG: Página ${validPageNumber} → tamaño: ${pageWidth}x${pageHeight} pts")
        println("DEBUG: Coords Flutter (top-left): x=$x, y=$y")
        println("DEBUG: Coords PDF (bottom-left):  x=$clampedX, y=$clampedY (w=$width, h=$height)")

        val appearance = signer.signatureAppearance
        appearance.setReason(reason)
        appearance.setLocation(location)
        appearance.setPageNumber(validPageNumber)
        appearance.setPageRect(Rectangle(clampedX, clampedY, width, height))

        val dateStr = java.text.SimpleDateFormat("dd/MM/yyyy HH:mm:ss", java.util.Locale("es", "EC")).format(java.util.Date())

        // Configurar apariencia visual: QR a la izquierda + texto a la derecha
        if (qrBytes != null && qrBytes.isNotEmpty()) {
            try {
                val imageData = ImageDataFactory.create(qrBytes)
                appearance.setRenderingMode(PdfSignatureAppearance.RenderingMode.GRAPHIC_AND_DESCRIPTION)
                appearance.setSignatureGraphic(imageData)
                println("DEBUG: QR image configurado en apariencia de firma (${qrBytes.size} bytes)")
            } catch (e: Exception) {
                println("WARN: No se pudo configurar QR en firma: ${e.message}")
                // Fallback: solo texto
            }
        }
        appearance.setLayer2Text("Firmado electrónicamente por:\n$signerName\n$dateStr")
        signer.fieldName = "SoloFirmaSignature_${System.currentTimeMillis()}"

        // ── 6. Componentes criptográficos ──────────────────────────────────────
        val digest: IExternalDigest = BouncyCastleDigest()
        val signature: IExternalSignature = PrivateKeySignature(
            privateKey, DigestAlgorithms.SHA256, BouncyCastleProvider.PROVIDER_NAME
        )
        val tsaClient   = TSAClientBouncyCastle("http://timestamp.digicert.com")
        val ocspClient  = OcspClientBouncyCastle(null)
        val crlClient   = CrlClientOnline()

        // ── 7. Firma CMS (PKCS7) ───────────────────────────────────────────────
        //
        // Se usa bcChain (re-codificada vía BouncyCastle) para garantizar que Adobe
        // pueda leer el certificado embebido en el CMS y mostrar los detalles del firmante.
        //
        // estimatedSize = 30000: el timestamp real de DigiCert incluye su cadena completa
        // (~15-20 KB), superando el valor por defecto de iText (~12 KB).
        signer.signDetached(
            digest,
            signature,
            bcChain,   // ← certificados re-codificados en formato BouncyCastle
            null,      // sin CRL inline (se añade via DSS en paso 2)
            null,      // sin OCSP inline (se añade via DSS en paso 2)
            tsaClient,
            30000,     // espacio suficiente para timestamp DigiCert
            PdfSigner.CryptoStandard.CMS
        )

        // ── 8. Añadir DSS/LTV en modo append (paso 2) ─────────────────────────
        try {
            addDssLtvInfo(outputPath, ocspClient, crlClient)
            println("INFO: DSS/LTV añadido correctamente")
        } catch (e: Exception) {
            // La firma es válida aunque falle el LTV (e.g. CA ecuatoriana sin OCSP accesible)
            println("WARN: No se pudo añadir DSS/LTV: ${e.message}")
        }

        return outputPath
    }

    /**
     * Añade Document Security Store (DSS) con datos LTV a un PDF ya firmado,
     * en modo append para no invalidar la firma existente.
     */
    private fun addDssLtvInfo(
        pdfPath: String,
        ocspClient: OcspClientBouncyCastle,
        crlClient: CrlClientOnline
    ) {
        val tempPath = "$pdfPath.ltv.tmp"
        val reader   = PdfReader(pdfPath)
        val writer   = PdfWriter(tempPath)
        val pdfDoc   = com.itextpdf.kernel.pdf.PdfDocument(
            reader, writer, StampingProperties().useAppendMode()
        )
        try {
            AdobeLtvEnabling(pdfDoc).enable()
            pdfDoc.close()

            // Atomic rename: backup → rename → cleanup para evitar pérdida de datos
            val originalFile = File(pdfPath)
            val tempFile     = File(tempPath)
            val backupFile   = File("$pdfPath.bak")

            originalFile.renameTo(backupFile)
            if (tempFile.renameTo(originalFile)) {
                backupFile.delete()
                println("INFO: AdobeLtvEnabling completado")
            } else {
                // Rollback: restaurar backup
                backupFile.renameTo(originalFile)
                tempFile.delete()
                throw Exception("Atomic rename failed — original restaurado desde backup")
            }
        } catch (e: Exception) {
            pdfDoc.close()
            File(tempPath).delete()
            throw e
        }
    }

    private fun saveFileToDownloads(sourcePath: String, fileName: String): String? {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) throw Exception("El archivo fuente no existe")

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/SoloFirma")
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("No se pudo crear entrada en MediaStore")
            contentResolver.openOutputStream(uri)?.use { out ->
                FileInputStream(sourceFile).use { it.copyTo(out) }
            }
            MediaScannerConnection.scanFile(this, arrayOf(uri.path), null, null)
            "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)}/SoloFirma/$fileName"
        } else {
            val solofirmaDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "SoloFirma"
            ).also { it.mkdirs() }
            val destFile = File(solofirmaDir, fileName)
            sourceFile.copyTo(destFile, overwrite = true)
            MediaScannerConnection.scanFile(this, arrayOf(destFile.absolutePath), null, null)
            destFile.absolutePath
        }
    }
}
