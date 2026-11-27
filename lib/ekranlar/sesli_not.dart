import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ai/ai_ayarlar.dart';
import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'kayit_sonrasi.dart';
import 'onay_penceresi.dart';

/// Sesli not ekranını açar; not kaydedilirse "Kaydedildi" mesajı gösterir.
Future<void> sesliNotAc() async {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final not = await nav.push<Not>(MaterialPageRoute(builder: (_) => const SesliNotEkrani()));
  if (not != null) await sesliSonrasi(not);
}

/// Sesli not kaydedilince çıkan özet penceresi: yapay zeka bu notu düzenlesin mi?
/// Genel anahtar kapalıysa anahtar kapalı gelir, istersen bu not için açabilirsin.
Future<void> sesliSonrasi(Not not) async {
  final ctx = navigatorKey.currentContext;
  if (ctx == null || !AiAyarlar.instance.anahtarVar) {
    await kayitSonrasi(not, kayitMesaji: 'Sesli not kaydedildi');
    return;
  }
  final genelAcik = AiAyarlar.instance.otomatik;
  var acik = genelAcik;
  final tamam = await showDialog<bool>(
    context: ctx,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: const Text('Sesli not kaydedildi'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Renk.zemin, borderRadius: BorderRadius.circular(12)),
            child: SingleChildScrollView(child: Text(not.metin)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yapay zeka düzenlesin'),
            subtitle: Text(genelAcik
                ? 'Çalışma saatinde kategori, başlık ve tarih önerir.'
                : 'Ayarlardaki genel anahtar kapalı. Açarsan bu not hemen düzenlenir.'),
            value: acik,
            onChanged: (v) => setS(() => acik = v),
          ),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tamam'))],
      ),
    ),
  );
  final secim = tamam == true ? acik : genelAcik;
  not.aiDisi = !secim;
  await Depo.instance.notGuncelle(not, dokunma: false);
  if (secim && !genelAcik) {
    await onayPenceresiAc(not.id, canli: true, gonder: true);
  } else {
    await kayitSonrasi(not, kayitMesaji: 'Sesli not kaydedildi');
  }
}

/// Sesli notun metin birikimi. Tanıma servisi duraklamada cümleyi "ara sonuç" olarak kapatıp yenisine
/// sıfırdan başlar; bu sınıf eski cümleleri atmaz, hepsini biriktirir.
class SesMetni {
  String kesinlesen = '';
  String parca = '';

  String get tum => [kesinlesen, parca].where((s) => s.trim().isNotEmpty).join(' ').trim();

  void _ekle(String metin) {
    final t = metin.trim();
    if (t.isEmpty) return;
    // Durma anında zaten eklenmiş aynı metin ikinci kez eklenmesin.
    if (kesinlesen.endsWith(t)) return;
    kesinlesen = '$kesinlesen $t'.trim();
  }

  /// Yeni gelen kısmi yazı, bekleyen parçanın devamı mı? (Servis bazen duraklamadan sonra
  /// işaret vermeden yeni cümleye sıfırdan başlar.)
  static bool devamMi(String eski, String yeni) {
    String ilk(String s) => s.trim().toLowerCase().split(RegExp(r'\s+')).first;
    final a = ilk(eski), b = ilk(yeni);
    final n = a.length < b.length ? a.length : b.length;
    if (n == 0) return true;
    final k = n < 3 ? n : 3;
    return a.substring(0, k) == b.substring(0, k);
  }

  /// [nihai]: oturum bitti. [ara]: servis bu cümleyi kapattı, sonrası yeni cümle.
  void sonuc(String kelimeler, {required bool nihai, bool ara = false}) {
    if (nihai || ara) {
      // Boş gelirse (sessizlikte olur) bekleyen parça silinmez.
      _ekle(kelimeler.trim().isNotEmpty ? kelimeler : parca);
      parca = '';
      return;
    }
    if (kelimeler.trim().isEmpty) return; // yeni oturumun boş kısmı eski parçayı ezmez
    if (parca.trim().isNotEmpty && !devamMi(parca, kelimeler)) _ekle(parca);
    parca = kelimeler;
  }

  /// Tanıma durdu: bekleyen parçayı kalıcı yap.
  void durdu() {
    _ekle(parca);
    parca = '';
  }
}

/// Konuşmayı not olarak kaydetmeden sadece yazıya çevirip döner (liste maddeleri için).
Future<String?> sesliMetinAl() async {
  final nav = navigatorKey.currentState;
  if (nav == null) return null;
  return nav.push<String>(MaterialPageRoute(builder: (_) => const SesliNotEkrani(sadeceMetin: true)));
}

class SesliNotEkrani extends StatefulWidget {
  /// true ise "Bitir"e basınca not kaydedilmez, yazıya çevrilen metin geri döner.
  final bool sadeceMetin;
  const SesliNotEkrani({super.key, this.sadeceMetin = false});

  @override
  State<SesliNotEkrani> createState() => _SesliNotEkraniState();
}

class _SesliNotEkraniState extends State<SesliNotEkrani> {
  final _ses = SpeechToText();
  final _metin = SesMetni();
  bool _bitti = false;
  bool _dinliyor = false;
  String? _hata;
  String? _dil;
  Timer? _yenidenBaslat;

  String get _tumMetin => _metin.tum;
  String get _kesinlesen => _metin.kesinlesen;
  String get _parca => _metin.parca;

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
    setState(() => _metin.sonuc(r.recognizedWords,
        nihai: r.finalResult, ara: r.resultTypeValue == ResultType.intermediate));
  }

  void _durum(String durum) {
    if (durum == SpeechToText.doneStatus || durum == SpeechToText.notListeningStatus) {
      _metin.durdu();
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
    if (widget.sadeceMetin) {
      Navigator.pop(context, metin);
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
        backgroundColor: Renk.zemin,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _iptal, tooltip: 'İptal'),
        title: Text(widget.sadeceMetin ? 'Sesle madde ekle' : 'Sesli not'),
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
                  color: _hata != null ? Colors.grey : Renk.vurgu,
                  shape: BoxShape.circle,
                  boxShadow: _dinliyor
                      ? [BoxShadow(color: Renk.vurgu.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 8)]
                      : null,
                ),
                child: Icon(Icons.mic, color: Renk.vurguUstu, size: 56),
              ),
              const SizedBox(height: 16),
              Text(
                _hata ?? (_dinliyor ? 'Dinliyorum… Bitince "Bitir"e bas.' : 'Hazırlanıyor…'),
                textAlign: TextAlign.center,
                style: yazi.titleSmall?.copyWith(color: _hata != null ? Renk.hata : Renk.yazi),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Renk.kart,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Renk.sinir),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: _kesinlesen, style: TextStyle(color: Renk.yazi)),
                      if (_parca.isNotEmpty)
                        TextSpan(
                            text: '${_kesinlesen.isEmpty ? '' : ' '}$_parca',
                            style: TextStyle(color: Renk.yazi.withValues(alpha: 0.55))),
                      if (_tumMetin.isEmpty)
                        TextSpan(
                            text: 'Konuştukların burada yazıya dönüşecek.',
                            style: TextStyle(color: Renk.yazi.withValues(alpha: 0.4))),
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
