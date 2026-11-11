import 'package:flutter/material.dart';
import '../models/app_models.dart';

class PriorityBarData {
  final CasePriority priority;
  final int count;

  PriorityBarData(this.priority, this.count);
}

class PriorityBarChartWidget extends StatelessWidget {
  final List<PriorityBarData> data;

  const PriorityBarChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    int maxVal = 1;
    for (var item in data) {
      if (item.count > maxVal) maxVal = item.count;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'จำนวนเคสแต่ละ Priority',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 135, // Increased height to prevent RenderFlex bottom overflow
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((item) {
                final heightFactor = (item.count / maxVal).clamp(0.1, 1.0);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${item.count}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 28,
                        height: 70 * heightFactor,
                        decoration: BoxDecoration(
                          color: item.priority.color,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.priority.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
