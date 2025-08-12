import 'package:flutter/material.dart';

class DraggableSignatureBox extends StatefulWidget {
  final Function(Offset position) onPositionChanged;

  const DraggableSignatureBox({Key? key, required this.onPositionChanged}) : super(key: key);

  @override
  _DraggableSignatureBoxState createState() => _DraggableSignatureBoxState();
}

class _DraggableSignatureBoxState extends State<DraggableSignatureBox> {
  // Posición inicial del cuadro en la pantalla
  Offset _position = const Offset(100, 100);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        // Detecta cuando el usuario arrastra el dedo
        onPanUpdate: (details) {
          setState(() {
            // Actualiza la posición del cuadro
            _position += details.delta;
            widget.onPositionChanged(_position);
          });
        },
        child: Container(
          width: 150, // Ancho del área de la firma
          height: 75, // Alto del área de la firma
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue,
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.withOpacity(0.2), // Un poco de color para que se vea
          ),
          child: const Center(
            child: Text(
              'Arrastra aquí tu firma',
              style: TextStyle(color: Colors.blue, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// CÓMO USARLO EN TU PANTALLA DE PREVISUALIZACIÓN:
//
// Stack(
//   children: [
//     // 1. Tu visor de PDF aquí abajo
//     PdfViewerWidget(),
//
//     // 2. El cuadro de la firma encima
//     DraggableSignatureBox(
//       onPositionChanged: (position) {
//         // Aquí guardas la posición final para luego estampar el QR
//         print('Nueva posición de la firma: $position');
//       },
//     ),
//   ],
// )
