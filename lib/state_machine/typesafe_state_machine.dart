import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/subjects.dart';

abstract class MachineState {
  const MachineState();
}

abstract class MachineEvent {
  const MachineEvent();
}

typedef TransitionHandler<S extends MachineState, E extends MachineEvent> =
    S? Function(S state, E event);

final class IllegalTransitionException implements Exception {
  final MachineState fromState;
  final MachineEvent event;
  const IllegalTransitionException(this.fromState, this.event);

  @override
  String toString() {
    return 'IllegalTransitionException: No transition rule defined for state $fromState and event $event';
  }
}

abstract class TypeSafeStateMachine<
  S extends MachineState,
  E extends MachineEvent
> {
  final BehaviorSubject<S> _controller;

  S get state => _controller.value;
  Stream<S> get stateStream => _controller.stream;

  TypeSafeStateMachine(S initial)
    : _controller = BehaviorSubject<S>.seeded(initial);

  final List<TransitionHandler<S, E>> _transitionRules = [];

  void when(TransitionHandler<S, E> rule) {
    _transitionRules.add(rule);
  }

  void dispatch(E event) {
    for (final rule in _transitionRules) {
      final newState = rule(state, event);
      if (newState != null) {
        _controller.add(newState);
        return;
      }
    }

    throw IllegalTransitionException(state, event);
  }

  void dispose() {
    _controller.close();
  }

  @protected
  void setState(S newState) {
    _controller.add(newState);
  }
}
