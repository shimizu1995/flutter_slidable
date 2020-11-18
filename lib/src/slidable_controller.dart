import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _defaultMovementDuration = Duration(milliseconds: 200);
const _defaultCurve = Curves.ease;

abstract class ActionPaneConfiguration {
  bool canChangeRatio(double ratio);
  double get extentRatio;
}

enum SlidableControllerProperty {
  endGesture,
  dismissGesture,
  resizeRequest,
  sign,
  ratio,
}

enum GestureDirection {
  opening,
  closing,
}

@immutable
class ResizeRequest {
  const ResizeRequest(this.duration, this.onDismissed);

  final Duration duration;
  final VoidCallback onDismissed;
}

@immutable
class DismissGesture {
  DismissGesture(this.endGesture);
  final EndGesture endGesture;
}

@immutable
class EndGesture {
  EndGesture(this.velocity);
  final double velocity;
}

class OpeningGesture extends EndGesture {
  OpeningGesture(double velocity) : super(velocity);
}

class ClosingGesture extends EndGesture {
  ClosingGesture(double velocity) : super(velocity);
}

class StillGesture extends EndGesture {
  StillGesture(this.direction) : super(0);

  final GestureDirection direction;
  bool get opening => direction == GestureDirection.opening;
  bool get closing => direction == GestureDirection.closing;
}

/// Represents a way to control a slidable from outside.
class SlidableController with ChangeNotifier {
  SlidableController(TickerProvider vsync)
      : _animationController = AnimationController(vsync: vsync) {
    _animationController.addListener(_notifyAnimationChanged);
  }

  final List<SlidableControllerProperty> _changedProperties =
      <SlidableControllerProperty>[];
  final AnimationController _animationController;

  bool enableStartActionPane = false;
  bool enableEndActionPane = false;

  ActionPaneConfiguration actionPaneConfiguration;

  bool acceptRatio(double ratio) {
    return ratio == 0 ||
        ((ratio > 0 && enableStartActionPane) ||
                (ratio < 0 && enableEndActionPane)) &&
            (actionPaneConfiguration == null ||
                actionPaneConfiguration.canChangeRatio(ratio.abs()));
  }

  SlidableControllerProperty get lastChangedProperty => _changedProperties.last;

  Animation<double> get animation => _animationController.view;

  void _notifyPropertyListeners(SlidableControllerProperty property) {
    _changedProperties.add(property);
    notifyListeners();
    _changedProperties.removeLast();
  }

  EndGesture get endGesture => _endGesture;
  EndGesture _endGesture;
  @protected
  set endGesture(EndGesture value) {
    if (_endGesture != value) {
      _endGesture = value;
      _notifyPropertyListeners(SlidableControllerProperty.endGesture);
    }
  }

  DismissGesture get dismissGesture => _dismissGesture;
  DismissGesture _dismissGesture;
  set dismissGesture(DismissGesture value) {
    if (_dismissGesture != value) {
      _dismissGesture = value;
      _notifyPropertyListeners(SlidableControllerProperty.dismissGesture);
    }
  }

  ResizeRequest get resizeRequest => _resizeRequest;
  ResizeRequest _resizeRequest;
  set resizeRequest(ResizeRequest value) {
    if (_resizeRequest != value) {
      _resizeRequest = value;
      _notifyPropertyListeners(SlidableControllerProperty.resizeRequest);
    }
  }

  double get sign => _sign;
  double _sign = 0;
  @protected
  set sign(double value) {
    if (_sign != value) {
      _sign = value;
      _notifyPropertyListeners(SlidableControllerProperty.sign);
    }
  }

  void _notifyAnimationChanged() {
    sign = _animationController.value.sign * _sign;
    _notifyPropertyListeners(SlidableControllerProperty.ratio);
  }

  /// The ratio between -1 and 1 representing the actual.
  ///
  /// When [ratio] is equals to 0, none of the action panels are visible.
  /// Within the interval [-1, 0[, the end action panel is visible.
  /// Within the interval ]0, 1], the start action panel is visible.
  double get ratio => _animationController.value * _sign;
  set ratio(double value) {
    if (ratio != value && acceptRatio(value)) {
      _animationController.value = value.abs();
      sign = value.sign;
      _notifyPropertyListeners(SlidableControllerProperty.ratio);
    }
  }

  void handleEndGesture(double velocity, GestureDirection direction) {
    if (velocity == 0) {
      endGesture = StillGesture(direction);
    } else if (velocity.sign == sign) {
      endGesture = OpeningGesture(velocity);
    } else {
      endGesture = ClosingGesture(velocity.abs());
    }
  }

  TickerFuture close({
    Duration duration = _defaultMovementDuration,
    Curve curve = _defaultCurve,
  }) {
    return _animationController.animateTo(
      0,
      duration: duration,
      curve: curve,
    );
  }

  TickerFuture open({
    Duration duration = _defaultMovementDuration,
    Curve curve = _defaultCurve,
  }) {
    assert(actionPaneConfiguration != null);
    assert(duration != null);
    return openTo(
      actionPaneConfiguration.extentRatio,
      duration: duration,
      curve: curve,
    );
  }

  TickerFuture openTo(
    double ratio, {
    Duration duration = _defaultMovementDuration,
    Curve curve = _defaultCurve,
  }) {
    assert(ratio != null && ratio >= -1 && ratio <= 1);
    assert(duration != null);
    return _animationController.animateTo(
      ratio,
      duration: duration,
      curve: curve,
    );
  }

  Future<void> dismiss(
    ResizeRequest request, {
    Duration duration = _defaultMovementDuration,
    Curve curve = _defaultCurve,
  }) async {
    await _animationController.animateTo(
      1,
      duration: _defaultMovementDuration,
      curve: curve,
    );
    resizeRequest = request;
  }

  @override
  void dispose() {
    _animationController.removeListener(_notifyAnimationChanged);
    _animationController.dispose();
    super.dispose();
  }
}
