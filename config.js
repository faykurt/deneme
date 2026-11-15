/* ============================================================
   SİTE AYARLARI — canlıya almadan önce burayı doldurun
   ============================================================ */
window.SITE_CONFIG = {
  // WhatsApp numarası: ülke koduyla, başında + ve boşluk olmadan. Örn: 905551112233
  whatsappNumber: "90XXXXXXXXXX",

  // Talepler ve olaylar için Google Apps Script web uygulaması adresi (KURULUM.md, 2. adım).
  // Boş bırakılırsa veriler yalnızca ziyaretçinin tarayıcısında saklanır (test modu).
  endpoint: "",

  // Google Analytics 4 ölçüm kimliği. Örn: G-ABCDE12345  (boşsa devre dışı)
  ga4Id: "",

  // Microsoft Clarity proje kimliği (boşsa devre dışı)
  clarityId: "",

  // Fiyatlar TASLAKTIR. Gerçek fiyatlarla değiştirin. (TL, KDV dahil/hariç notunu da güncelleyin)
  priceNote: "Fiyatlar tahminidir; kur ve temin koşullarına göre kesinleşir. KDV ayrıca belirtilecektir.",
  // Güven maddeleri: YALNIZCA gerçekten yerine getirebileceğiniz sözleri bırakın.
  trust: [
    { icon: "💳", title: "Ön ödeme yok", text: "Ödeme, ürün teslim edildikten sonra yapılır." },
    { icon: "↩️", title: "Ücretsiz iade", text: "Teslimatta memnun kalmazsanız iade kargo ücreti bizden." },
    { icon: "💬", title: "WhatsApp'tan birebir destek", text: "Fiyat, teslim süresi ve içerik hakkında doğrudan yazışırsınız." },
  ],

  products: [
    {
      id: "b4-orijinal",
      set: "Bayley-4",
      type: "Orijinal",
      title: "Bayley-4 Orijinal Set",
      desc: "Üretici tarafından üretilen, yurt dışından temin edilecek orijinal komple set.",
      price: 95000,
      currency: "₺",
      badge: "Orijinal",
    },
    {
      id: "b4-yerli",
      set: "Bayley-4",
      type: "Yerli Üretim",
      title: "Bayley-4 Yerli Üretim Set",
      desc: "Set içeriğinin bir bölümü yerelde 3D baskı ve diğer yöntemlerle üretilir. Orijinale göre daha ulaşılabilir fiyat.",
      price: 35000,
      currency: "₺",
      badge: "Yerli Üretim",
    },
  ],
};
