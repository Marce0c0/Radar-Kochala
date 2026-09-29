import 'package:flutter/material.dart';
import '../../data/models/report.dart';
import '../../core/theme/app_theme.dart';
class StaffPageIntro extends StatelessWidget {
  const StaffPageIntro({super.key, required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.ink)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xff78908d)))]));
}

class StaffHeading extends StatelessWidget {
  const StaffHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 9), child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.ink)));
}

class StaffStatsRow extends StatelessWidget {
  const StaffStatsRow({super.key, required this.items});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => Row(children: items.map((item) => Expanded(child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xffe1e9e6))), child: Column(children: [Text(item.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.teal)), Text(item.$2, style: const TextStyle(fontSize: 10, color: Color(0xff78908d)))])))).toList());
}

class StaffReportTile extends StatelessWidget {
  const StaffReportTile({super.key, required this.report, required this.action, required this.onTap});
  final Report report;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xffdcebe6), child: Icon(Icons.report, color: AppTheme.teal)), title: Text(report.title, maxLines: 1), subtitle: Text('${report.neighborhood} · ${report.time}'), trailing: FilledButton(onPressed: onTap, child: Text(action))));
}

class StaffSegmented extends StatelessWidget {
  const StaffSegmented({super.key, required this.options, required this.selected, required this.onChanged});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, children: options.map((option) => ChoiceChip(label: Text(option), selected: option == selected, onSelected: (_) => onChanged(option))).toList());
}

class StaffWorkerTile extends StatelessWidget {
  const StaffWorkerTile({super.key, required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(color: selected ? const Color(0xffe5f1ed) : Colors.white, child: ListTile(leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: AppTheme.teal), title: Text(name), subtitle: const Text('En línea'), onTap: onTap));
}

