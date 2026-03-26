import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/hue_service.dart';
import '../services/tapo_service.dart';

// Crestron-inspired colour system (approved demo)
class _C {
  static const bg = Color(0xFF0E0D0B);
  static const card = Color(0xFF1A1916);
  static const amber = Color(0xFFE8A61C);
  static const gold = Color(0xFFC4A96B);
  static const t1 = Color(0xFFF0EDE6);
  static const t2 = Color(0xFF8A8778);
  static const t3 = Color(0xFF5A5848);
  static const border = Color(0x0DFFFFFF);
  static const borderOn = Color(0x1FE8A61C);
  static const track = Color(0x0FFFFFFF);
  static const togOff = Color(0xFF2A2924);
  static const togKnob = Color(0xFF5A5848);
}

class LightDevice {
  final String id, name, source;
  bool on;
  int brightness;
  String? tapoIp;
  LightDevice({required this.id, required this.name, required this.source, this.on = false, this.brightness = 0, this.tapoIp});
  bool get isPlug => source == 'tapo_plug';
  bool get isDimmable => source != 'tapo_plug';
}

class LightScene {
  String id, name, emoji;
  int brightness;
  bool builtin;
  LightScene({required this.id, required this.name, required this.emoji, required this.brightness, this.builtin = false});
}

class LightGroup {
  String id, name;
  List<String> lightIds;
  LightGroup({required this.id, required this.name, required this.lightIds});
}

class LightingPage extends StatefulWidget {
  const LightingPage({super.key});
  @override
  State<LightingPage> createState() => _LightingPageState();
}

class _LightingPageState extends State<LightingPage> {
  bool _loading = true;
  String? _error;
  List<LightDevice> _lights = [];
  final List<LightGroup> _groups = [];
  final List<LightScene> _scenes = [
    LightScene(id: 's1', name: 'Bright', emoji: '☀️', brightness: 100, builtin: true),
    LightScene(id: 's2', name: 'Relax', emoji: '🌅', brightness: 60),
    LightScene(id: 's3', name: 'Dim', emoji: '🌙', brightness: 25),
    LightScene(id: 's4', name: 'Evening', emoji: '🌆', brightness: 45),
    LightScene(id: 's5', name: 'Focus', emoji: '💼', brightness: 80),
    LightScene(id: 's6', name: 'All Off', emoji: '⚫', brightness: 0, builtin: true),
  ];
  String? _activeScene;
  StreamSubscription<HueEvent>? _sseSub;
  Map<String, String> _v2ToV1 = {};
  StreamSubscription<Map<String, TapoDevice>>? _tapoSub;

  @override
  void initState() { super.initState(); _loadLights(); _startSSE(); _startTapo(); }

  @override
  void dispose() { _sseSub?.cancel(); _tapoSub?.cancel(); HueService.stopEventStream(); TapoService.stopPolling(); super.dispose(); }

  void _startTapo() {
    TapoService.startPolling();
    _tapoSub = TapoService.stateStream.listen((tapoDevices) {
      if (!mounted) return;
      setState(() {
        // Update existing Tapo lights
        for (final l in _lights.where((x) => x.source == 'tapo_plug' || x.source == 'tapo_strip')) {
          final td = tapoDevices.values.firstWhere(
            (t) => t.nickname == l.name || t.alias == l.id.replaceFirst('tapo:', ''),
            orElse: () => TapoDevice(alias:'',nickname:'',ip:'',mac:'',type:'',model:'',isPlug:true),
          );
          if (td.ip.isNotEmpty) {
            l.on = td.on;
            l.brightness = td.brightness;
            l.tapoIp = td.ip;
          }
        }
        // Add any new Tapo devices not yet in the list
        for (final td in tapoDevices.values) {
          if (td.ip.isEmpty) continue;
          final exists = _lights.any((l) => l.tapoIp == td.ip || l.name == td.nickname);
          if (!exists) {
            _lights.add(LightDevice(
              id: 'tapo:${td.alias}',
              name: td.nickname,
              source: td.isPlug ? 'tapo_plug' : 'tapo_strip',
              on: td.on,
              brightness: td.brightness,
              tapoIp: td.ip,
            ));
          }
        }
      });
    });
  }

  void _startSSE() async {
    // Build V2→V1 ID mapping
    _v2ToV1 = await HueService.getV2ToV1Map();
    
    _sseSub = HueService.startEventStream().listen((event) {
      if (!mounted) return;
      
      if (event.type == HueEventType.deviceAdded || event.type == HueEventType.lightAdded) {
        // New device/light — full reload to pick it up
        _loadLights();
        return;
      }
      
      if (event.type == HueEventType.lightChanged) {
        // Find the V1 ID from the V2 resource ID
        final v1Id = _v2ToV1[event.resourceId];
        if (v1Id == null) return;
        
        final hueId = 'hue:$v1Id';
        final light = _lights.cast<LightDevice?>().firstWhere((l) => l?.id == hueId, orElse: () => null);
        if (light == null) return;
        
        setState(() {
          if (event.on != null) light.on = event.on!;
          if (event.brightness != null) light.brightness = event.brightness!;
          if (!light.on) light.brightness = 0;
        });
      }
    });
  }

  Future<void> _loadLights() async {
    setState(() { _loading = true; _error = null; });
    try {
      final hueLights = await HueService.getLights();
      final lights = <LightDevice>[];
      hueLights.forEach((id, hl) {
        if (!hl.reachable) return; // Skip unreachable lights
        lights.add(LightDevice(id: 'hue:$id', name: hl.name, source: 'hue', on: hl.on, brightness: hl.brightness));
      });
      // Load Tapo devices from proxy
      try {
        final tapoDevices = await TapoService.fetchDevices();
        for (final td in tapoDevices.values) {
          if (td.ip.isEmpty) continue;
          lights.add(LightDevice(
            id: 'tapo:${td.alias}',
            name: td.nickname,
            source: td.isPlug ? 'tapo_plug' : 'tapo_strip',
            on: td.on,
            brightness: td.brightness,
            tapoIp: td.ip,
          ));
        }
      } catch (_) {
        // Proxy not running — add known devices as offline placeholders
        lights.addAll([
          LightDevice(id: 'tapo:ucl1', name: 'Kitchen UCL 1', source: 'tapo_plug'),
          LightDevice(id: 'tapo:ucl2', name: 'Kitchen UCL 2', source: 'tapo_plug'),
          LightDevice(id: 'tapo:picture', name: 'Lounge Picture', source: 'tapo_plug'),
          LightDevice(id: 'tapo:strip1', name: 'Cerise Lightstrip', source: 'tapo_strip'),
          LightDevice(id: 'tapo:strip2', name: 'Cerise Lightstrip 2', source: 'tapo_strip'),
        ]);
      }
      setState(() { _lights = lights; _loading = false; });
    } catch (e) {
      setState(() {
        _lights = [
          LightDevice(id:'h12',name:'Entrance 1',source:'hue'),LightDevice(id:'h21',name:'Entrance 2',source:'hue'),
          LightDevice(id:'h1',name:'Entrance 3',source:'hue'),LightDevice(id:'h16',name:'Entrance 4',source:'hue'),
          LightDevice(id:'h15',name:'Laundry 1',source:'hue'),LightDevice(id:'h13',name:'Laundry 2',source:'hue'),
          LightDevice(id:'h14',name:'Laundry 3',source:'hue'),LightDevice(id:'h17',name:'Lounge Light',source:'hue'),
          LightDevice(id:'h7',name:'Alfresco',source:'hue'),LightDevice(id:'h8',name:'MBLight 1',source:'hue'),
          LightDevice(id:'h20',name:'MBLight 2',source:'hue'),
          LightDevice(id:'t1',name:'Kitchen UCL 1',source:'tapo_plug',on:true),
          LightDevice(id:'t2',name:'Kitchen UCL 2',source:'tapo_plug',on:true),
          LightDevice(id:'tp',name:'Lounge Picture',source:'tapo_plug',on:true),
          LightDevice(id:'ts1',name:'Cerise Lightstrip',source:'tapo_strip'),
          LightDevice(id:'ts2',name:'Cerise Lightstrip 2',source:'tapo_strip'),
        ];
        _loading = false; _error = 'Demo mode — Hue bridge unreachable';
      });
    }
  }

  Future<void> _toggleLight(LightDevice l) async {
    HapticFeedback.lightImpact();
    setState(() {
      if (l.isPlug) { l.on = !l.on; }
      else { if (l.on) { l.on = false; l.brightness = 0; } else { l.on = true; l.brightness = 100; } }
    });
    if (l.source == 'hue') {
      final hid = l.id.replaceFirst('hue:', '');
      try { l.on ? await HueService.setBrightness(hid, l.brightness) : await HueService.turnOff(hid); } catch (_) {}
    } else if ((l.source == 'tapo_plug' || l.source == 'tapo_strip') && l.tapoIp != null && l.tapoIp!.isNotEmpty) {
      try {
        if (l.on) {
          if (l.source == 'tapo_strip') { await TapoService.setBrightness(l.tapoIp!, 100); }
          else { await TapoService.turnOn(l.tapoIp!); }
        } else {
          await TapoService.turnOff(l.tapoIp!);
        }
      } catch (_) {}
    }
  }

  Future<void> _setBri(LightDevice l, int pct) async {
    setState(() { l.brightness = pct; l.on = pct > 0; });
    if (l.source == 'hue') {
      final hid = l.id.replaceFirst('hue:', '');
      try { pct > 0 ? await HueService.setBrightness(hid, pct) : await HueService.turnOff(hid); } catch (_) {}
    } else if (l.source == 'tapo_strip' && l.tapoIp != null && l.tapoIp!.isNotEmpty) {
      try { pct > 0 ? await TapoService.setBrightness(l.tapoIp!, pct) : await TapoService.turnOff(l.tapoIp!); } catch (_) {}
    }
  }

  void _activateScene(LightScene s) {
    HapticFeedback.mediumImpact();
    setState(() {
      _activeScene = s.id;
      for (final l in _lights) {
        if (l.isPlug) { l.on = s.brightness > 0; }
        else { l.brightness = s.brightness; l.on = s.brightness > 0; }
      }
    });
    for (final l in _lights.where((x) => x.source == 'hue')) {
      final hid = l.id.replaceFirst('hue:', '');
      l.on ? HueService.setBrightness(hid, l.brightness).catchError((_){}) : HueService.turnOff(hid).catchError((_){});
    }
    for (final l in _lights.where((x) => x.source == 'tapo_plug' || x.source == 'tapo_strip')) {
      if (l.tapoIp == null || l.tapoIp!.isEmpty) continue;
      if (l.on) {
        if (l.source == 'tapo_strip') { TapoService.setBrightness(l.tapoIp!, s.brightness > 0 ? s.brightness : 100).catchError((_){}); }
        else { TapoService.turnOn(l.tapoIp!).catchError((_){}); }
      } else {
        TapoService.turnOff(l.tapoIp!).catchError((_){});
      }
    }
  }

  void _adjustAll(int delta) {
    HapticFeedback.selectionClick();
    setState(() { for (final l in _lights) { if (!l.isPlug && l.on) { l.brightness = (l.brightness + delta).clamp(0, 100); if (l.brightness == 0) l.on = false; } } });
  }

  @override
  Widget build(BuildContext context) {
    final onC = _lights.where((l) => l.on).length;
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 960 ? 3 : w >= 580 ? 2 : 1;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: _loading ? const Center(child: CircularProgressIndicator(color: _C.amber))
            : RefreshIndicator(
                onRefresh: _loadLights,
                color: _C.amber,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  children: [
                    // Header
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$onC of ${_lights.length} on', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.t3, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      const Text('Lights', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _C.t1, letterSpacing: -0.5)),
                      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFFF6B6B)))),
                    ])),
                    const SizedBox(height: 20),

                    // Scenes
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('Scenes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _C.t3, letterSpacing: 2))),
                    const SizedBox(height: 10),
                    SizedBox(height: 40, child: ListView.separated(
                      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 4),
                      itemCount: _scenes.length + 1, separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        if (i == _scenes.length) return _sceneChip('+ Scene', null, false, onTap: () => _showSceneDialog(null));
                        final s = _scenes[i];
                        return _sceneChip('${s.emoji} ${s.name}', s, _activeScene == s.id, onTap: () => _activateScene(s), onLongPress: () => _showSceneDialog(s));
                      },
                    )),
                    const SizedBox(height: 24),

                    // All Lights header
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [
                      _circBtn('−', () => _adjustAll(-10)),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('All Lights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.t1))),
                      _circBtn('+', () => _adjustAll(10)),
                      const SizedBox(width: 12),
                      GestureDetector(onTap: () => _showGroupDialog(null), child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _C.borderOn), color: const Color(0x0AE8A61C)),
                        child: const Text('+ Group', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.amber)),
                      )),
                    ])),
                    const SizedBox(height: 16),

                    // Lights grid
                    ..._buildGrid(cols),

                    // Add group
                    const SizedBox(height: 12),
                    GestureDetector(onTap: () => _showGroupDialog(null), child: Container(
                      padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x14C4A96B))),
                      child: const Center(child: Text('+ Add Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _C.t3))),
                    )),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _buildGrid(int cols) {
    final grouped = <String>{};
    final sections = <Widget>[];

    for (final g in _groups) {
      final gl = g.lightIds.map((id) => _lights.cast<LightDevice?>().firstWhere((l) => l?.id == id, orElse: () => null)).whereType<LightDevice>().toList();
      for (final l in gl) grouped.add(l.id);
      final anyOn = gl.any((l) => l.on);

      sections.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Row(children: [
        Text(g.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.t2)),
        const Spacer(),
        GestureDetector(onTap: () => _showGroupDialog(g), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: _C.border)),
          child: const Text('Edit', style: TextStyle(fontSize: 10, color: _C.t3)),
        )),
        const SizedBox(width: 6),
        _AmberToggle(value: anyOn, onChanged: (_) {
          HapticFeedback.lightImpact();
          setState(() { for (final l in gl) { if (anyOn) { l.on = false; if (!l.isPlug) l.brightness = 0; } else { l.on = true; if (!l.isPlug) l.brightness = 100; } } });
          for (final l in gl) {
            if (l.source == 'hue') {
              final hid = l.id.replaceFirst('hue:', '');
              l.on ? HueService.setBrightness(hid, l.brightness).catchError((_){}) : HueService.turnOff(hid).catchError((_){});
            } else if ((l.source == 'tapo_plug' || l.source == 'tapo_strip') && l.tapoIp != null && l.tapoIp!.isNotEmpty) {
              if (l.on) {
                if (l.source == 'tapo_strip') { TapoService.setBrightness(l.tapoIp!, 100).catchError((_){}); }
                else { TapoService.turnOn(l.tapoIp!).catchError((_){}); }
              } else { TapoService.turnOff(l.tapoIp!).catchError((_){}); }
            }
          }
        }),
      ])));

      sections.add(_wrapGrid(cols, gl.map((l) => _lightCard(l)).toList()));
    }

    final ug = _lights.where((l) => !grouped.contains(l.id)).toList();
    if (ug.isNotEmpty && _groups.isNotEmpty) {
      sections.add(Padding(padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text('Ungrouped', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.t3.withOpacity(0.4)))));
    }
    sections.add(_wrapGrid(cols, ug.map((l) => _lightCard(l)).toList()));

    return sections;
  }

  Widget _wrapGrid(int cols, List<Widget> cards) {
    if (cols == 1) return Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 8), child: c)).toList());
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += cols) {
      final row = <Widget>[];
      for (var j = 0; j < cols; j++) {
        if (i + j < cards.length) { row.add(Expanded(child: cards[i + j])); }
        else { row.add(const Expanded(child: SizedBox())); }
        if (j < cols - 1) row.add(const SizedBox(width: 8));
      }
      rows.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: row)));
    }
    return Column(children: rows);
  }

  Widget _lightCard(LightDevice l) {
    final on = l.on;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? _C.borderOn : _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
          if (on) BoxShadow(color: _C.amber.withOpacity(0.04), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(l.isPlug ? PhosphorIcons.plug(PhosphorIconsStyle.fill) : PhosphorIcons.lightbulb(on ? PhosphorIconsStyle.fill : PhosphorIconsStyle.light),
              size: 18, color: on ? _C.amber : _C.t3),
          const SizedBox(width: 10),
          Expanded(child: Text(l.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: on ? _C.t1 : _C.t3))),
          Text(l.isPlug ? (on ? 'ON' : 'OFF') : (on ? '${l.brightness}%' : 'Off'),
              style: TextStyle(fontSize: l.isPlug ? 11 : 13, fontWeight: FontWeight.w700, color: on ? _C.amber : _C.t3)),
          const SizedBox(width: 10),
          _AmberToggle(value: on, onChanged: (_) => _toggleLight(l)),
        ]),
        if (l.isDimmable) ...[
          const SizedBox(height: 14),
          _BrightnessBar(value: l.brightness / 100, isOn: on, onChanged: (v) => _setBri(l, (v * 100).round())),
        ],
      ]),
    );
  }

  Widget _sceneChip(String label, LightScene? s, bool active, {required VoidCallback onTap, VoidCallback? onLongPress}) {
    return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0x1FE8A61C) : _C.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? _C.borderOn : _C.border),
        boxShadow: active ? [BoxShadow(color: _C.amber.withOpacity(0.1), blurRadius: 12)] : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? _C.amber : s == null ? _C.gold : _C.t2)),
    ));
  }

  Widget _circBtn(String label, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _C.card, border: Border.all(color: _C.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Center(child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: _C.t2))),
    ));
  }

  // ─── Group dialog ───
  void _showGroupDialog(LightGroup? existing) {
    final nc = TextEditingController(text: existing?.name ?? '');
    final sel = Set<String>.from(existing?.lightIds ?? []);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Dialog(
      backgroundColor: const Color(0xFF141310), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width >= 900 ? 720 : MediaQuery.of(ctx).size.width >= 600 ? 560 : 380, maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(existing != null ? 'Edit Group' : 'New Group', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.t1)),
          const SizedBox(height: 14),
          TextField(controller: nc, style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(hintText: 'Group name', hintStyle: const TextStyle(color: _C.t3), filled: true, fillColor: _C.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11))),
          const SizedBox(height: 12),
          const Text('Select Lights', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _C.t2)),
          const SizedBox(height: 8),
          Flexible(child: LayoutBuilder(builder: (ctx, c) {
            final dc = c.maxWidth >= 500 ? 3 : c.maxWidth >= 300 ? 2 : 1;
            return GridView.builder(shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: dc, mainAxisSpacing: 4, crossAxisSpacing: 4, mainAxisExtent: 42),
              itemCount: _lights.length, itemBuilder: (ctx, i) {
                final l = _lights[i]; final s2 = sel.contains(l.id);
                return GestureDetector(onTap: () => ss(() => s2 ? sel.remove(l.id) : sel.add(l.id)),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: s2 ? const Color(0x0AE8A61C) : Colors.transparent, border: Border.all(color: s2 ? _C.borderOn : Colors.transparent)),
                    child: Row(children: [
                      Container(width: 18, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), color: s2 ? _C.amber : const Color(0x0AFFFFFF)),
                        child: s2 ? const Icon(Icons.check, size: 12, color: Colors.black) : null),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: s2 ? _C.t1 : _C.t3))),
                      Text(l.isPlug ? 'Plug' : 'Light', style: const TextStyle(fontSize: 10, color: Color(0x11FFFFFF))),
                    ])));
              });
          })),
          const SizedBox(height: 14),
          Row(children: [
            if (existing != null) Expanded(child: TextButton(onPressed: () { setState(() => _groups.removeWhere((g) => g.id == existing.id)); Navigator.pop(ctx); },
                child: const Text('Delete', style: TextStyle(color: Color(0xFFD04040))))),
            Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _C.t3)))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: () {
              final n = nc.text.trim(); if (n.isEmpty || sel.isEmpty) return;
              setState(() { if (existing != null) { existing.name = n; existing.lightIds = sel.toList(); }
                else { _groups.add(LightGroup(id: 'g${DateTime.now().millisecondsSinceEpoch}', name: n, lightIds: sel.toList())); } });
              Navigator.pop(ctx);
            }, style: ElevatedButton.styleFrom(backgroundColor: _C.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)))),
          ]),
        ]))))));
  }

  // ─── Scene dialog ───
  void _showSceneDialog(LightScene? existing) {
    final nc = TextEditingController(text: existing?.name ?? '');
    String em = existing?.emoji ?? '✨'; int bri = existing?.brightness ?? 70;
    final ems = ['☀️','🌅','🌙','🌆','💼','⚫','✨','🔥','💤','🎬','🍽️','🎉'];
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Dialog(
      backgroundColor: const Color(0xFF141310), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(existing != null ? 'Edit Scene' : 'New Scene', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _C.t1)),
        const SizedBox(height: 14),
        Wrap(spacing: 5, runSpacing: 5, children: ems.map((e) => GestureDetector(onTap: () => ss(() => em = e),
          child: Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              color: e == em ? const Color(0x14E8A61C) : const Color(0x08FFFFFF), border: Border.all(color: e == em ? _C.borderOn : _C.border)),
            child: Center(child: Text(e, style: const TextStyle(fontSize: 16)))))).toList()),
        const SizedBox(height: 12),
        TextField(controller: nc, style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(hintText: 'Scene name', hintStyle: const TextStyle(color: _C.t3), filled: true, fillColor: _C.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _BrightnessBar(value: bri / 100, isOn: true, onChanged: (v) => ss(() => bri = (v * 100).round()))),
          const SizedBox(width: 12),
          Text('$bri%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.amber)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          if (existing != null && !existing.builtin) Expanded(child: TextButton(onPressed: () { setState(() => _scenes.removeWhere((s) => s.id == existing.id)); Navigator.pop(ctx); },
              child: const Text('Delete', style: TextStyle(color: Color(0xFFD04040))))),
          Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _C.t3)))),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(onPressed: () {
            final n = nc.text.trim(); if (n.isEmpty) return;
            setState(() { if (existing != null) { existing.name = n; existing.emoji = em; existing.brightness = bri; }
              else { _scenes.add(LightScene(id: 's${DateTime.now().millisecondsSinceEpoch}', name: n, emoji: em, brightness: bri)); } });
            Navigator.pop(ctx);
          }, style: ElevatedButton.styleFrom(backgroundColor: _C.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)))),
        ]),
      ])))));
  }
}

// ─── AMBER TOGGLE ───
class _AmberToggle extends StatelessWidget {
  final bool value; final ValueChanged<bool> onChanged;
  const _AmberToggle({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () { HapticFeedback.lightImpact(); onChanged(!value); },
      child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 44, height: 24,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: value ? _C.amber : _C.togOff,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]),
        child: AnimatedAlign(duration: const Duration(milliseconds: 200), curve: Curves.easeInOutCubicEmphasized,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(margin: const EdgeInsets.all(3), width: 18, height: 18,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: value ? [Colors.white, const Color(0xFFE0E0E0)] : [_C.togKnob, const Color(0xFF4A4838)]),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 3, offset: const Offset(0, 1))])))));
  }
}

// ─── BRIGHTNESS BAR — gradient fill + fader thumb ───
class _BrightnessBar extends StatelessWidget {
  final double value; final bool isOn; final ValueChanged<double> onChanged;
  const _BrightnessBar({required this.value, required this.isOn, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      return GestureDetector(
        onPanStart: (d) => onChanged((d.localPosition.dx / w).clamp(0.0, 1.0)),
        onPanUpdate: (d) => onChanged((d.localPosition.dx / w).clamp(0.0, 1.0)),
        onTapDown: (d) => onChanged((d.localPosition.dx / w).clamp(0.0, 1.0)),
        child: SizedBox(height: 30, child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
          // Track
          Container(height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: _C.track,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))])),
          // Fill
          if (isOn && value > 0) Positioned(left: 0, top: 9, bottom: 9, width: w * value,
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(colors: [Color(0xFFA04800), Color(0xFFD4820A), Color(0xFFEDAC1A), Color(0xFFF5D070)]),
              boxShadow: [BoxShadow(color: _C.amber.withOpacity(0.25), blurRadius: 8), BoxShadow(color: _C.amber.withOpacity(0.4), blurRadius: 2)]))),
          // Fader thumb
          Positioned(left: (w * value - 14).clamp(0, w - 28), top: 0,
            child: Container(width: 28, height: 30,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: isOn ? [Colors.white, const Color(0xFFE8E8E8), const Color(0xFFD0D0D0)]
                      : [const Color(0xFF555555), const Color(0xFF444444), const Color(0xFF333333)]),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 2)),
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 2, offset: const Offset(0, 1))]),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (_) =>
                Padding(padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Container(width: 12, height: 1.5, decoration: BoxDecoration(borderRadius: BorderRadius.circular(1),
                    color: isOn ? Colors.black.withOpacity(0.12) : Colors.white.withOpacity(0.1)))))))),
        ])));
    });
  }
}
