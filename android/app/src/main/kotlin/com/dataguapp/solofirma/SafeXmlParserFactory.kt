package com.dataguapp.solofirma

import com.itextpdf.kernel.utils.DefaultSafeXmlParserFactory
import javax.xml.parsers.DocumentBuilderFactory

class SafeXmlParserFactory : DefaultSafeXmlParserFactory() {
    override fun createDocumentBuilderInstance(namespaceAware: Boolean, ignoringComments: Boolean): javax.xml.parsers.DocumentBuilder {
        val factory = DocumentBuilderFactory.newInstance()
        try {
            factory.isXIncludeAware = false // Disable XInclude to avoid Android error
        } catch (e: Exception) {
            // Ignore if not supported
        }
        try {
            factory.isNamespaceAware = namespaceAware
        } catch (e: Exception) {
            // Ignore
        }
        try {
            factory.isIgnoringComments = ignoringComments
        } catch (e: Exception) {
            // Ignore
        }
        return factory.newDocumentBuilder()
    }
}
