/* ============================================================
   SİTE AYARLARI — canlıya almadan önce burayı doldurun
   ============================================================ */
window.SITE_CONFIG = {
  // WhatsApp numarası: ülke koduyla, başında + ve boşluk olmadan. Örn: 905551112233
  whatsappNumber: "90XXXXXXXXXX",

  // Talepler ve olaylar için Google Apps Script web uygulaması adresi (KURULUM.md, 2. adım).
  // Boş bırakılırsa hiçbir şey kaydedilmez (test modu).
  endpoint: "",

  // Fiyat aralıkları (£). Değiştirmek için priceText alanlarını düzenleyin.
  priceNote: "Tahmini fiyat aralıkları. Kesin fiyat WhatsApp'ta iletilir.",

  // Talep gönderildikten sonra gösterilir. YALNIZCA gerçekten yerine getirebileceğiniz sözleri bırakın.
  trust: [
    { icon: "💳", text: "Ön ödeme yok. Ödeme teslimattan sonra." },
    { icon: "↩️", text: "Ücretsiz iade." },
  ],

  products: [
    {
      id: "b4-orijinal",
      set: "Bayley-4",
      type: "Orijinal",
      title: "Orijinal Set",
      desc: "Üreticinin komple seti, yurt dışından temin edilir.",
      priceText: "£1.600 – £1.800",
      badge: "Orijinal",
    },
    {
      id: "b4-yerli",
      set: "Bayley-4",
      type: "Yerli Üretim",
      title: "Yerli Üretim Set",
      desc: "Orijinal setteki ürünlerin ağırlık, gramaj ve renk gibi özelliklerine göre birebir örneği üretilir.",
      priceText: "£500 – £600",
      badge: "Yerli Üretim",
    },
  ],
};
