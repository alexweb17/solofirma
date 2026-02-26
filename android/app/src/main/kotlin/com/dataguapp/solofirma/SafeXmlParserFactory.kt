package com.dataguapp.solofirma
import com.itextpdf.kernel.utils.IXmlParserFactory
import javax.xml.parsers.DocumentBuilder
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.parsers.ParserConfigurationException
import org.xml.sax.XMLReader
import javax.xml.parsers.SAXParserFactory
import org.xml.sax.SAXException

class SafeXmlParserFactory : IXmlParserFactory {
    override fun createDocumentBuilderInstance(namespaceAware: Boolean, ignoringComments: Boolean): DocumentBuilder {
        val factory = DocumentBuilderFactory.newInstance()
        factory.isNamespaceAware = namespaceAware
        factory.isIgnoringComments = ignoringComments
        // Configuraciones de seguridad para evitar ataques XXE
        try {
            factory.setFeature("http://javax.xml.XMLConstants/feature/secure-processing", true)
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
            factory.setFeature("http://xml.org/sax/features/external-general-entities", false)
            factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false)
            factory.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false)
            factory.setXIncludeAware(false)
            factory.isExpandEntityReferences = false
        } catch (e: Exception) {
            // Algunas features pueden no estar soportadas en todos los parsers de Android, ignoramos el error
            e.printStackTrace()
        }
        return factory.newDocumentBuilder()
    }

    override fun createXMLReaderInstance(namespaceAware: Boolean, validating: Boolean): XMLReader {
        val factory = SAXParserFactory.newInstance()
        factory.isNamespaceAware = namespaceAware
        factory.isValidating = validating
        
        try {
            factory.setFeature("http://javax.xml.XMLConstants/feature/secure-processing", true)
            factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
            factory.setFeature("http://xml.org/sax/features/external-general-entities", false)
            factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return factory.newSAXParser().xmlReader
    }
}
