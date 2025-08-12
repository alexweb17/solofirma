import 'package:flutter/material.dart';

class DraggableSignatureBox extends StatefulWidget {
  final Function(Offset position) onPositionChanged;

  const DraggableSignatureBox({super.key, required this.onPositionChanged});

  @override
  _DraggableSignatureBoxState createState() => _DraggableSignatureBoxState();
}

class _DraggableSignatureBoxState extends State<DraggableSignatureBox> {
  Offset _position = const Offset(100, 100);
  // 1. Añadimos un estado para saber si el cuadro está bloqueado.
  bool _isLocked = false;

  @override
  Widget build(BuildContext context) {
    // 2. El color ahora depende del estado _isLocked.
    final Color boxColor = _isLocked ? Colors.green : Colors.black;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      // 3. El GestureDetector ahora maneja más gestos.
      child: GestureDetector(
        // ARRASTRAR: Solo funciona si el cuadro NO está bloqueado.
        onPanUpdate: (details) {
          if (!_isLocked) {
            setState(() {
              _position += details.delta;
              widget.onPositionChanged(_position);
            });
          }
        },
        // UN TOQUE: Bloquea el cuadro.
        onTap: () {
          setState(() {
            _isLocked = true;
          });
        },
        // DOBLE TOQUE: Desbloquea el cuadro.
        onDoubleTap: () {
          setState(() {
            _isLocked = false;
          });
        },
        child: Container(
          width: 150,
          height: 75,
          decoration: BoxDecoration(
            border: Border.all(
              color: boxColor, // El color del borde cambia
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
            color: boxColor.withOpacity(0.2), // El color del fondo cambia
          ),
          child: Center(
            child: Text(
              // 4. El texto también cambia para guiar al usuario.
              _isLocked
                  ? 'Firma ubicada.\nDoble-toque para mover.'
                  : 'Arrastra para ubicar.\nUn toque para fijar.',
              style: TextStyle(color: boxColor, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
