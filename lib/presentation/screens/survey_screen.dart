import 'package:flutter/material.dart';
import 'package:pilgrims_3d/services/api/api_service.dart' as api;
import 'package:pilgrims_3d/presentation/providers/locale_provider.dart';
import 'package:provider/provider.dart';

const _kAccent = Color(0xFF365037);   // primaryGreen
const _kAccent2 = Color(0xFF5A6B57);  // secondaryGreen
const _kGreen = Color(0xFF4A7C59);    // verde éxito
const _kRed = Color(0xFFB85C38);      // terracota/marrón-rojo natural

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  // Q1 — Perfil
  String? _perfil;
  final TextEditingController _perfilOtroCtrl = TextEditingController();

  // Q2 — Dispositivo
  String? _dispositivo;

  // Q3 — Registro/acceso (1-5)
  int? _registro;

  // Q4 — Navegación (1-5)
  int? _navegacion;

  // Q5 — Diseño visual (1-5)
  int? _disenyo;

  // Q6 — Mapa de rutas (1-5)
  int? _mapa;

  // Q7 — Info POI (1-5)
  int? _poi;

  // Q8 — Guías de audio
  String? _audio;

  // Q9 — AR / 3D
  String? _ar;

  // Q10 — Funcionalidad más útil
  String? _funcUtil;

  // Q11 — Usarías la app
  String? _usaria;

  // Q12 — Funcionalidades destacadas (checkboxes)
  final Set<String> _funcDestacadas = {};
  final TextEditingController _funcOtroCtrl = TextEditingController();

  // Q13 — Mejorarías / echas en falta
  final TextEditingController _mejoraCtrl = TextEditingController();

  // Q14 — Puntuación global (1-10)
  int? _puntuacion;

  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _perfilOtroCtrl.dispose();
    _funcOtroCtrl.dispose();
    _mejoraCtrl.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Submit
  // -----------------------------------------------------------------------

  Future<void> _submitSurvey() async {
    final surveyData = <String, dynamic>{
      if (_perfil != null)
        'perfil': _perfil == 'Otro' ? _perfilOtroCtrl.text.trim() : _perfil,
      if (_dispositivo != null) 'dispositivo': _dispositivo,
      if (_registro != null) 'registro_sencillo': _registro,
      if (_navegacion != null) 'navegacion_intuitiva': _navegacion,
      if (_disenyo != null) 'diseno_atractivo': _disenyo,
      if (_mapa != null) 'mapa_claro': _mapa,
      if (_poi != null) 'poi_suficiente': _poi,
      if (_audio != null) 'guias_audio': _audio,
      if (_ar != null) 'realidad_aumentada': _ar,
      if (_funcUtil != null) 'funcionalidad_util': _funcUtil,
      if (_usaria != null) 'usaria_app': _usaria,
      if (_funcDestacadas.isNotEmpty)
        'funcionalidades_destacadas': _funcDestacadas
            .map((f) => f == 'Otro' ? _funcOtroCtrl.text.trim() : f)
            .where((f) => f.isNotEmpty)
            .toList(),
      if (_mejoraCtrl.text.trim().isNotEmpty) 'mejoras': _mejoraCtrl.text.trim(),
      if (_puntuacion != null) 'puntuacion_global': _puntuacion,
    };

    setState(() => _sending = true);
    final ok = await api.send_survey(surveyData);
    if (!mounted) return;
    final loc = context.read<LocaleProvider>();
    setState(() {
      _sending = false;
      _sent = ok;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? loc.translate('survey_success')
              : loc.translate('survey_error'),
        ),
        backgroundColor: ok ? _kGreen : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Build helpers
  // -----------------------------------------------------------------------

  Widget _questionCard({
    required int number,
    required String question,
    bool required = true,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kAccent, _kAccent2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          question,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (required)
                        const Text(
                          ' *',
                          style: TextStyle(
                            color: _kAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _chipOption<T>({
    required String label,
    required T value,
    required T? groupValue,
    required void Function(T) onSelected,
    bool isCheckbox = false,
  }) {
    final selected = groupValue == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kAccent.withOpacity(0.08) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kAccent : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: isCheckbox ? BorderRadius.circular(5) : null,
                shape: isCheckbox ? BoxShape.rectangle : BoxShape.circle,
                border: Border.all(
                  color: selected ? _kAccent : Colors.grey.shade400,
                  width: 2,
                ),
                color: selected ? _kAccent : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? _kAccent : Colors.black87,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Radio group helper
  Widget _radioGroup<T>({
    required List<_RadioOption<T>> options,
    required T? groupValue,
    required void Function(T?) onChanged,
    Widget? extraWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...options.map(
          (opt) => _chipOption<T>(
            label: opt.label,
            value: opt.value,
            groupValue: groupValue,
            onSelected: (v) => onChanged(v),
          ),
        ),
        if (extraWidget != null) extraWidget,
      ],
    );
  }

  /// Scale (Likert) row
  Widget _scaleRow({
    required int min,
    required int max,
    required String minLabel,
    required String maxLabel,
    required int? value,
    required void Function(int) onChanged,
  }) {
    final count = max - min + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              minLabel,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
            Text(
              maxLabel,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(count, (index) {
            final v = min + index;
            final selected = value == v;
            final t = count == 1 ? 0.5 : index / (count - 1);
            final color = Color.lerp(_kRed, _kGreen, t)!;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected ? color : color.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                    border: selected ? Border.all(color: color, width: 2) : null,
                    boxShadow: selected
                        ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 6, offset: const Offset(0, 3))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$v',
                    style: TextStyle(
                      color: selected ? Colors.white : color.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // Main build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.watch<LocaleProvider>();
    final t = loc.translate;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EF),
      appBar: AppBar(
        title: Text(t('survey_screen_title')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kAccent, _kAccent2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.star_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t('survey_header_title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('survey_header_subtitle'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t('survey_required_note'),
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Q1 — Perfil ─────────────────────────────────────────────
            _questionCard(
              number: 1,
              question: t('survey_q1'),
              child: Column(
                children: [
                  _radioGroup<String>(
                    groupValue: _perfil,
                    onChanged: (v) => setState(() => _perfil = v),
                    options: [
                      _RadioOption(t('survey_q1_pilgrim'), 'Peregrino/a'),
                      _RadioOption(t('survey_q1_hiker'), 'Senderista'),
                      _RadioOption(t('survey_q1_tourist'), 'Turista cultural'),
                      _RadioOption(t('survey_q1_researcher'), 'Investigador/a'),
                      _RadioOption(t('survey_other'), 'Otro'),
                    ],
                  ),
                  if (_perfil == 'Otro')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextField(
                        controller: _perfilOtroCtrl,
                        decoration: InputDecoration(
                          hintText: t('survey_specify_profile'),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kAccent, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Q2 — Dispositivo ─────────────────────────────────────────
            _questionCard(
              number: 2,
              question: t('survey_q2'),
              child: _radioGroup<String>(
                groupValue: _dispositivo,
                onChanged: (v) => setState(() => _dispositivo = v),
                options: const [
                  _RadioOption('Android', 'Android'),
                  _RadioOption('iOS', 'iOS'),
                  _RadioOption('Web', 'Web'),
                ],
              ),
            ),

            // ── Q3 — Registro (scale 1-5) ────────────────────────────────
            _questionCard(
              number: 3,
              question: t('survey_q3'),
              child: _scaleRow(
                min: 1,
                max: 5,
                minLabel: t('survey_q3_min'),
                maxLabel: t('survey_q3_max'),
                value: _registro,
                onChanged: (v) => setState(() => _registro = v),
              ),
            ),

            // ── Q4 — Navegación (scale 1-5) ──────────────────────────────
            _questionCard(
              number: 4,
              question: t('survey_q4'),
              child: _scaleRow(
                min: 1,
                max: 5,
                minLabel: t('survey_q4_min'),
                maxLabel: t('survey_q4_max'),
                value: _navegacion,
                onChanged: (v) => setState(() => _navegacion = v),
              ),
            ),

            // ── Q5 — Diseño (scale 1-5) ──────────────────────────────────
            _questionCard(
              number: 5,
              question: t('survey_q5'),
              child: _scaleRow(
                min: 1,
                max: 5,
                minLabel: t('survey_q5_min'),
                maxLabel: t('survey_q5_max'),
                value: _disenyo,
                onChanged: (v) => setState(() => _disenyo = v),
              ),
            ),

            // ── Q6 — Mapa (scale 1-5) ────────────────────────────────────
            _questionCard(
              number: 6,
              question: t('survey_q6'),
              child: _scaleRow(
                min: 1,
                max: 5,
                minLabel: t('survey_q6_min'),
                maxLabel: t('survey_q6_max'),
                value: _mapa,
                onChanged: (v) => setState(() => _mapa = v),
              ),
            ),

            // ── Q7 — Info POI (scale 1-5) ────────────────────────────────
            _questionCard(
              number: 7,
              question: t('survey_q7'),
              child: _scaleRow(
                min: 1,
                max: 5,
                minLabel: t('survey_q7_min'),
                maxLabel: t('survey_q7_max'),
                value: _poi,
                onChanged: (v) => setState(() => _poi = v),
              ),
            ),

            // ── Q8 — Guías de audio ──────────────────────────────────────
            _questionCard(
              number: 8,
              question: t('survey_q8'),
              child: _radioGroup<String>(
                groupValue: _audio,
                onChanged: (v) => setState(() => _audio = v),
                options: [
                  _RadioOption(t('survey_q8_great'), 'Muy buenas'),
                  _RadioOption(t('survey_q8_good'), 'Buenas'),
                  _RadioOption(t('survey_q8_improvable'), 'Mejorables'),
                  _RadioOption(t('survey_q8_not_tried'), 'No las probé'),
                ],
              ),
            ),

            // ── Q9 — AR / 3D ─────────────────────────────────────────────
            _questionCard(
              number: 9,
              question: t('survey_q9'),
              child: _radioGroup<String>(
                groupValue: _ar,
                onChanged: (v) => setState(() => _ar = v),
                options: [
                  _RadioOption(t('survey_q9_ok'), 'Sí, funcionó sin problemas'),
                  _RadioOption(t('survey_q9_issue'), 'Sí, pero tuve algún problema'),
                  _RadioOption(t('survey_q9_not_tried'), 'No lo probé'),
                ],
              ),
            ),

            // ── Q10 — Funcionalidad más útil ─────────────────────────────
            _questionCard(
              number: 10,
              question: t('survey_q10'),
              child: _radioGroup<String>(
                groupValue: _funcUtil,
                onChanged: (v) => setState(() => _funcUtil = v),
                options: [
                  _RadioOption(t('survey_q10_ar'), 'survey_q10_ar'),
                  _RadioOption(t('survey_q10_viewer'), 'survey_q10_viewer'),
                  _RadioOption(t('survey_q10_both'), 'Ambas por igual'),
                  _RadioOption(t('survey_q10_not_tried'), 'No lo probé'),
                ],
              ),
            ),

            // ── Q11 — ¿Usarías la app? ───────────────────────────────────
            _questionCard(
              number: 11,
              question: t('survey_q11'),
              child: _radioGroup<String>(
                groupValue: _usaria,
                onChanged: (v) => setState(() => _usaria = v),
                options: [
                  _RadioOption(t('survey_q11_def_yes'), 'Definitivamente sí'),
                  _RadioOption(t('survey_q11_prob_yes'), 'Probablemente sí'),
                  _RadioOption(t('survey_q11_prob_no'), 'Probablemente no'),
                  _RadioOption(t('survey_q11_no'), 'No'),
                ],
              ),
            ),

            // ── Q12 — Funcionalidades destacadas (checkboxes) ────────────
            _questionCard(
              number: 12,
              question: t('survey_q12'),
              child: Column(
                children: [
                  ...[
                    (t('survey_q12_maps'), 'Mapas y navegación'),
                    (t('survey_q12_audio'), 'Guías de audio'),
                    (t('survey_q12_ar3d'), 'Realidad Aumentada y modelos 3D'),
                    (t('survey_q12_poi'), 'Puntos de Interés'),
                    (t('survey_q12_routes'), 'Crear rutas propias'),
                    (t('survey_other'), 'Otro'),
                  ].map((entry) => _chipOption<String>(
                    label: entry.$1,
                    value: entry.$2,
                    groupValue: _funcDestacadas.contains(entry.$2) ? entry.$2 : null,
                    isCheckbox: true,
                    onSelected: (v) {
                      setState(() {
                        if (_funcDestacadas.contains(v)) {
                          _funcDestacadas.remove(v);
                        } else {
                          _funcDestacadas.add(v);
                        }
                      });
                    },
                  )),
                  if (_funcDestacadas.contains('Otro'))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextField(
                        controller: _funcOtroCtrl,
                        decoration: InputDecoration(
                          hintText: t('survey_specify'),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _kAccent, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Q13 — ¿Qué mejorarías? (libre, no obligatorio) ──────────
            _questionCard(
              number: 13,
              question: t('survey_q13'),
              required: false,
              child: TextField(
                controller: _mejoraCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: t('survey_q13_hint'),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kAccent, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),

            // ── Q14 — Puntuación global (1-10) ───────────────────────────
            _questionCard(
              number: 14,
              question: t('survey_q14'),
              child: _scaleRow(
                min: 1,
                max: 10,
                minLabel: t('survey_q14_min'),
                maxLabel: t('survey_q14_max'),
                value: _puntuacion,
                onChanged: (v) => setState(() => _puntuacion = v),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                t('survey_privacy_note'),
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),

      // ── Botón Enviar ──────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _sent
              ? Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kGreen, Color(0xFF2ECC71)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _kGreen.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        t('survey_sent'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: _sending ? null : _submitSurvey,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: _sending
                          ? null
                          : const LinearGradient(
                              colors: [_kAccent, _kAccent2],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                      color: _sending ? Colors.grey.shade300 : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _sending
                          ? null
                          : [
                              BoxShadow(
                                color: _kAccent.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Center(
                      child: _sending
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  t('survey_submit'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

class _RadioOption<T> {
  final String label;
  final T value;
  const _RadioOption(this.label, this.value);
}
