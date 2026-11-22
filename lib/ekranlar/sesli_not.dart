import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'kayit_sonrasi.dart';

/// Sesli not ekranını açar; not kaydedilirse "Kaydedildi" mesajı gösterir.
Future<void> sesliNotAc() async {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final not = await nav.push<Not>(MaterialPageRoute(builder: (_) => const SesliNotEkrani()));
  if (not != null) await kayitSonrasi(not, kayitMesaji: 'Sesli not kaydedildi');
}

class SesliNotEkrani extends StatefulWidget {
  const SesliNotEkrani({super.key});

  @override
  State<SesliNotEkrani> createState() => _SesliNotEkraniState();
}

class _SesliNotEkraniState extends State<SesliNotEkrani> {
  final _ses = SpeechToText();
  String _kesinlesen = '';
  String _parca = '';
  bool _bitti = false;
  bool _dinliyor = false;
  String? _hata;
  String? _dil;
  Timer? _yenidenBaslat;

  String get _tumMetin => [_kesinlesen, _parca].where((s) => s.trim().isNotEmpty).join(' ').trim();

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  Future<void> _baslat() async {
    final hazir = await _ses.initialize(onStatus: _durum, onError: _hataGeldi);
    if (!mounted) return;
    if (!hazir) {
      setState(() => _hata = 'Ses tanıma başlatılamadı. Mikrofon iznini verdiğinden emin ol.');
      return;
    }
    final diller = await _ses.locales();
    final tr = diller.where((d) => d.localeId.toLowerCase().startsWith('tr'));
    _dil = tr.isNotEmpty ? tr.first.localeId : 'tr_TR';
    _dinle();
  }

  void _dinle() {
    if (_bitti || !mounted) return;
    _ses.listen(
      onResult: _sonuc,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        localeId: _dil,
        pauseFor: const Duration(seconds: 30),
        listenFor: const Duration(minutes: 10),
      ),
    );
    setState(() => _dinliyor = true);
  }

  void _sonuc(SpeechRecognitionResult r) {
    setState(() {
      if (r.finalResult) {
        if (r.recognizedWords.trim().isNotEmpty) {
          _kesinlesen = '$_kesinlesen ${r.recognizedWords}'.trim();
        }
        _parca = '';
      } else {
        _parca = r.recognizedWords;
      }
    });
  }

  void _durum(String durum) {
    if (durum == SpeechToText.doneStatus || durum == SpeechToText.notListeningStatus) {
      if (_parca.trim().isNotEmpty) {
        _kesinlesen = '$_kesinlesen $_parca'.trim();
        _parca = '';
      }
      if (mounted) setState(() => _dinliyor = false);
      // Sen "Bitir"e basana kadar dinlemeye devam et.
      if (!_bitti && _hata == null) {
        _yenidenBaslat?.cancel();
        _yenidenBaslat = Timer(const Duration(milliseconds: 400), () {
          if (!_ses.isListening) _dinle();
        });
      }
    }
  }

  void _hataGeldi(SpeechRecognitionError e) {
    final m = e.errorMsg;
    if (m.contains('network') || m.contains('server')) {
      setState(() => _hata = 'İnternet bağlantısı yok gibi görünüyor. '
          'Sesli not için internet gerekiyor, şimdilik yazılı not alabilirsin.');
    } else if (m.contains('permission')) {
      setState(() => _hata = 'Mikrofon izni verilmedi. Telefon ayarlarından Aklımda için mikrofon iznini açabilirsin.');
    } else if (m.contains('language')) {
      setState(() => _hata = 'Telefonunda Türkçe ses tanıma bulunamadı.');
    }
    // Diğer hatalar (sessizlik vb.) için dinleme kendiliğinden yeniden başlar.
  }

  Future<void> _bitir() async {
    _bitti = true;
    _yenidenBaslat?.cancel();
    await _ses.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    final metin = _tumMetin;
    if (!mounted) return;
    if (metin.isEmpty) {
      Navigator.pop(context);
      mesajGoster('Bir şey duyamadım, not kaydedilmedi.');
      return;
    }
    final not = await Depo.instance.notEkle(metin: metin, kaynak: Kaynak.sesli);
    if (mounted) Navigator.pop(context, not);
  }

  Future<void> _iptal() async {
    _bitti = true;
    _yenidenBaslat?.cancel();
    await _ses.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _bitti = true;
    _yenidenBaslat?.cancel();
    _ses.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yazi = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Renk.krem,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _iptal, tooltip: 'İptal'),
        title: const Text('Sesli not'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: _dinliyor ? 120 : 100,
                height: _dinliyor ? 120 : 100,
                decoration: BoxDecoration(
                  color: _hata != null ? Colors.grey : Renk.turuncu,
                  shape: BoxShape.circle,
                  boxShadow: _dinliyor
                      ? [BoxShadow(color: Renk.turuncu.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 8)]
                      : null,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 16),
              Text(
                _hata ?? (_dinliyor ? 'Dinliyorum… Bitince "Bitir"e bas.' : 'Hazırlanıyor…'),
                textAlign: TextAlign.center,
                style: yazi.titleSmall?.copyWith(color: _hata != null ? Colors.red.shade800 : Renk.kahve),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Renk.acikKrem,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x22000000)),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: _kesinlesen, style: const TextStyle(color: Renk.kahve)),
                      if (_parca.isNotEmpty)
                        TextSpan(
                            text: '${_kesinlesen.isEmpty ? '' : ' '}$_parca',
                            style: TextStyle(color: Renk.kahve.withValues(alpha: 0.55))),
                      if (_tumMetin.isEmpty)
                        TextSpan(
                            text: 'Konuştukların burada yazıya dönüşecek.',
                            style: TextStyle(color: Renk.kahve.withValues(alpha: 0.4))),
                    ]), style: yazi.titleMedium),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _bitir,
                  icon: const Icon(Icons.check),
                  label: const Text('Bitir', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
