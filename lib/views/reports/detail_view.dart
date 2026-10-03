import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../staff/field_worker_view.dart';
import '../widgets/status_pill.dart';

// Convertido a StatefulWidget para gestionar el estado de votación local.
class DetailView extends StatefulWidget {
  const DetailView({super.key, required this.report, this.isFromExecution = false});
  final Report report;
  final bool isFromExecution;

  @override
  State<DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<DetailView> {
  int _votes = 0;
  bool _voted = false;
  bool _votingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVotes();
  }

  Future<void> _loadVotes() async {
    try {
      final client = Supabase.instance.client;
      final result = await client
          .from('votes')
          .select('user_id')
          .eq('report_id', widget.report.id);
      final userId = client.auth.currentUser?.id;
      if (mounted) {
        setState(() {
          _votes = result.length;
          _voted = userId != null &&
              result.any((v) => v['user_id'] == userId);
        });
      }
    } catch (_) {}
  }

  Future<void> _reopenReport(BuildContext context, Report report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reportar resolución falsa?'),
        content: const Text('Si el problema no fue solucionado, este caso volverá a la cuadrilla y los técnicos responsables serán penalizados por la resolución falsa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reportar y Reabrir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final client = Supabase.instance.client;
      await client.from('reports').update({
        'status': 'reviewing' // Devuelve a revisión para que el operador asigne otro equipo o lo penalice
      }).eq('id', report.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte reabierto y enviado a auditoría.'), backgroundColor: Colors.redAccent));
        Navigator.pop(context); // Vuelve atrás para recargar
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al reabrir: $e')));
    }
  }

  Future<void> _toggleVote() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para votar.'),
          backgroundColor: Color(0xffd9684b),
        ),
      );
      return;
    }
    if (_votingLoading) return;

    setState(() => _votingLoading = true);
    try {
      if (_voted) {
        await client
            .from('votes')
            .delete()
            .eq('report_id', widget.report.id)
            .eq('user_id', userId);
        if (mounted) setState(() { _votes--; _voted = false; });
      } else {
        await client.from('votes').insert({
          'report_id': widget.report.id,
          'user_id': userId,
          'vote_value': 1,
        });
        if (mounted) setState(() { _votes++; _voted = true; });
      }
    } catch (e) {
      debugPrint('Error al registrar voto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar el voto: $e'),
            backgroundColor: const Color(0xffd9684b),
          ),
        );
      }
    }
    if (mounted) setState(() => _votingLoading = false);
  }

  void _showFullscreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(c),
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Report report = widget.report;
    final String? imageUrl = report.imageUrl;
    final _currentUser = Supabase.instance.client.auth.currentUser;
    final _isStaff = _currentUser != null && _currentUser.email != null && _currentUser.email!.endsWith('@alcaldia.cbba');

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detalle del reporte',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Solo renderiza el contenedor si hay una imagen presente
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            if (report.resolvedImageUrl != null && report.resolvedImageUrl!.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.report_problem, size: 16, color: Color(0xffd9684b)),
                            SizedBox(width: 4),
                            Text('Reportado', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xffd9684b))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GestureDetector(
                            onTap: () => _showFullscreenImage(context, imageUrl),
                            child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image_not_supported)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: AppTheme.teal),
                            SizedBox(width: 4),
                            Text('Resuelto', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.teal)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GestureDetector(
                            onTap: () => _showFullscreenImage(context, report.resolvedImageUrl!),
                            child: Image.network(report.resolvedImageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image_not_supported)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xffdcebe6),
                    boxShadow: [
                      BoxShadow(color: AppTheme.ink.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => _showFullscreenImage(context, imageUrl),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image_outlined, size: 50, color: Color(0xff78908d))),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Evidencia fotográfica del reporte',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
          
          if (report.resolvedImageUrl != null && report.resolvedImageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xffdcebe6),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.ink.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      report.resolvedImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Icon(Icons.broken_image_outlined,
                            size: 50, color: Color(0xff78908d)),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.green.withValues(alpha: 0.8)
                            ],
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Evidencia de Resolución (Técnico)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // --- TÍTULO Y ESTADO ---
          Text(
            report.title,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
                height: 1.2),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(status: report.status),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: report.severity == 'Alta' 
                      ? const Color(0xfffce8e8) 
                      : (report.severity == 'Media' ? const Color(0xfffef3c7) : const Color(0xffe8f4f2)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: report.severity == 'Alta' 
                      ? const Color(0xffd9684b).withOpacity(0.3) 
                      : (report.severity == 'Media' ? const Color(0xffd99a3d).withOpacity(0.3) : const Color(0xff2d8c7e).withOpacity(0.3)),
                  ),
                ),
                child: Text(
                  'Prioridad: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: report.severity == 'Alta' 
                      ? const Color(0xffd9684b) 
                      : (report.severity == 'Media' ? const Color(0xffd99a3d) : const Color(0xff2d8c7e)),
                  ),
                ),
              ),
              if (report.isAiVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xfff0edff),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xff7c3aed).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: Color(0xff7c3aed)),
                      SizedBox(width: 4),
                      Text(
                        'IA Verificado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff7c3aed),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Color(0xff668080)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report.neighborhood,
                        style: const TextStyle(
                            color: Color(0xff668080),
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- BOTÓN DE VOTO ---
          Row(
            children: [
              Text(
                'Reportado ${report.time}',
                style: const TextStyle(fontSize: 13, color: Color(0xff78908d)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleVote,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _voted
                        ? const Color(0xff2d8c7e)
                        : const Color(0xffe8f4f2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_votingLoading)
                        const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.white))
                      else
                        Icon(
                          _voted ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 16,
                          color: _voted
                              ? Colors.white
                              : const Color(0xff2d8c7e),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '$_votes ${_votes == 1 ? 'voto' : 'votos'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _voted
                              ? Colors.white
                              : const Color(0xff2d8c7e),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- DESCRIPCIÓN ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffe1e9e6)),
            ),
            child: Text(
              report.description,
              style: const TextStyle(
                  fontSize: 15, height: 1.6, color: Color(0xff344f4c)),
            ),
          ),
          
          if (report.resolutionDetail != null && report.resolutionDetail!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xfff0fdf4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffbbf7d0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.teal, size: 18),
                      SizedBox(width: 8),
                      Text('Detalle de Resolución', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.teal)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.resolutionDetail!,
                    style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xff344f4c)),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 30),

          // --- UBICACION ---
          if (report.latitude != null && report.longitude != null) ...[
            const Text(
              'Ubicación del problema',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink),
            ),
            const SizedBox(height: 14),
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffe1e9e6)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(report.latitude!, report.longitude!),
                    initialZoom: 16.5,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(report.latitude!, report.longitude!),
                          width: 40, height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${report.latitude},${report.longitude}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Navegar al punto'),
              ),
            ),
            const SizedBox(height: 30),
          ],

          // --- SEGUIMIENTO ---
          const Text(
            'Seguimiento de la alcaldía',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffe1e9e6)),
            ),
            child: Column(
              children: updatesFor(report).asMap().entries.map((e) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: e.value.completed
                        ? AppTheme.teal
                        : const Color(0xffdcebe6),
                    child: e.value.completed
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${e.key + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ink)),
                  ),
                  title: Text(
                    e.value.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: e.value.completed
                          ? AppTheme.ink
                          : const Color(0xff78908d),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(e.value.note,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xff668080))),
                  ),
                  isThreeLine: true,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // --- REABRIR REPORTE FALSO ---
          if (report.status == ReportStatus.resolved && !_isStaff) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xfffce8e8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xffd9684b).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿El problema persiste o el trabajo es falso?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xffd9684b), fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Si este caso ha sido marcado como resuelto de manera engañosa, reporta la falla para que la alcaldía penalice a los técnicos responsables y reasigne el trabajo.',
                    style: TextStyle(fontSize: 13, color: Color(0xffd9684b)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _reopenReport(context, report),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffd9684b),
                        side: const BorderSide(color: Color(0xffd9684b)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Reclamar Resolución Falsa', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (!widget.isFromExecution && report.status == ReportStatus.inProgress && _currentUser != null && _currentUser.email != null && _currentUser.email!.startsWith('trabajador')) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (widget.isFromExecution) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TaskExecutionView(report: report)));
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.build),
                label: const Text('Subir reporte de solución', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
