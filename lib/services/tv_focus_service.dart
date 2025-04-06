import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

class TVFocusService {
  static final TVFocusService _instance = TVFocusService._internal();
  factory TVFocusService() => _instance;
  TVFocusService._internal();

  final MethodChannel _channel =
      const MethodChannel('com.hotelstream.hotel_stream/tv_controls');
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'Root');

  // Keep track of focusable widgets
  final Map<String, FocusNode> _focusNodes = {};
  FocusNode? _currentFocus;

  void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'dpadEvent') {
      final String direction = call.arguments as String;
      _handleDPadEvent(direction);
    }
  }

  void _handleDPadEvent(String direction) {
    if (_currentFocus == null) {
      // If no focus, set it to the first available node
      if (_focusNodes.isNotEmpty) {
        _focusNodes.values.first.requestFocus();
        _currentFocus = _focusNodes.values.first;
      }
      return;
    }

    // Find the next focus based on direction
    FocusNode? nextFocus;
    switch (direction) {
      case 'up':
        nextFocus = _findNextFocus(Offset(0, -1));
        break;
      case 'down':
        nextFocus = _findNextFocus(Offset(0, 1));
        break;
      case 'left':
        nextFocus = _findNextFocus(Offset(-1, 0));
        break;
      case 'right':
        nextFocus = _findNextFocus(Offset(1, 0));
        break;
      case 'select':
        if (_currentFocus != null && _currentFocus!.context != null) {
          // Simulate a tap on the focused widget
          final RenderBox box =
              _currentFocus!.context!.findRenderObject() as RenderBox;
          final Offset position = box.localToGlobal(Offset.zero);
          final Size size = box.size;

          GestureBinding.instance.handlePointerEvent(PointerDownEvent(
            position: position + Offset(size.width / 2, size.height / 2),
          ));
          GestureBinding.instance.handlePointerEvent(PointerUpEvent(
            position: position + Offset(size.width / 2, size.height / 2),
          ));
        }
        break;
    }

    if (nextFocus != null) {
      nextFocus.requestFocus();
      _currentFocus = nextFocus;
    }
  }

  FocusNode? _findNextFocus(Offset direction) {
    if (_currentFocus == null || _currentFocus!.context == null) return null;

    final RenderBox currentBox =
        _currentFocus!.context!.findRenderObject() as RenderBox;
    final currentPosition = currentBox.localToGlobal(Offset.zero);

    FocusNode? bestCandidate;
    double bestDistance = double.infinity;

    for (final node in _focusNodes.values) {
      if (node == _currentFocus || node.context == null) continue;

      final RenderBox candidateBox =
          node.context!.findRenderObject() as RenderBox;
      final candidatePosition = candidateBox.localToGlobal(Offset.zero);

      final vector = candidatePosition - currentPosition;

      // Check if the candidate is in the right direction
      if ((direction.dx > 0 && vector.dx <= 0) ||
          (direction.dx < 0 && vector.dx >= 0) ||
          (direction.dy > 0 && vector.dy <= 0) ||
          (direction.dy < 0 && vector.dy >= 0)) {
        continue;
      }

      final distance = vector.distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestCandidate = node;
      }
    }

    return bestCandidate;
  }

  // Register a widget as focusable
  FocusNode registerFocusable(String id, {FocusNode? existingNode}) {
    print('TVFocusService: Registering focusable with id: $id');
    if (_focusNodes.containsKey(id)) {
      print('TVFocusService: Returning existing focus node for id: $id');
      return _focusNodes[id]!;
    }

    final node = existingNode ?? FocusNode(debugLabel: id);
    _focusNodes[id] = node;
    print(
        'TVFocusService: Created new focus node for id: $id, total nodes: ${_focusNodes.length}');

    // Add a listener to track focus changes
    node.addListener(() {
      if (node.hasFocus) {
        print('TVFocusService: Node $id gained focus');
        _currentFocus = node;
      }
    });

    return node;
  }

  // Unregister a focusable widget
  void unregisterFocusable(String id) {
    print('TVFocusService: Unregistering focusable with id: $id');
    if (_currentFocus == _focusNodes[id]) {
      print('TVFocusService: Current focus was on $id, setting to null');
      _currentFocus = null;
    }
    _focusNodes.remove(id);
    print(
        'TVFocusService: After unregistering, total nodes: ${_focusNodes.length}');
  }

  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    _currentFocus = null;
    _rootFocusNode.dispose();
  }
}
