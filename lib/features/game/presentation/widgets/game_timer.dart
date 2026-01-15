import 'dart:async';
import 'package:flutter/material.dart';

class GameTimer extends StatefulWidget {
  final int duration;
  final VoidCallback onTimeUp;

  const GameTimer({
    super.key,
    required this.duration,
    required this.onTimeUp,
  });

  @override
  State<GameTimer> createState() => _GameTimerState();
}

class _GameTimerState extends State<GameTimer> {
  late int _timeLeft;
  late int _totalDuration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _totalDuration = widget.duration;
    _timeLeft = widget.duration;
    _startTimer();
  }

  @override
  void didUpdateWidget(GameTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
       _timer?.cancel();
       _totalDuration = widget.duration;
       _timeLeft = widget.duration;
       _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          }
          
          if (_timeLeft <= 0) {
            timer.cancel();
            widget.onTimeUp();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine color based on time remaining
    final Color timerColor = _timeLeft <= 10 ? Colors.redAccent : Colors.white;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 70, // Rule: Larger Timer
          height: 70,
          child: CircularProgressIndicator(
            value: _totalDuration > 0 ? _timeLeft / _totalDuration : 0,
            valueColor: AlwaysStoppedAnimation<Color>(timerColor), // Rule: Dynamic Color
            backgroundColor: Colors.white24, // Rule: Subtle Track
            strokeWidth: 10, // Rule: Max Stroke
            strokeCap: StrokeCap.round,
          ),
        ),
        Text(
          '$_timeLeft',
          style: TextStyle(
            fontSize: 24, // Rule: Bigger Timer Text
            fontWeight: FontWeight.w900, // Rule: ExtraBold
            color: timerColor, // Rule: Dynamic Color
          ),
        ),
      ],
    );
  }
}
