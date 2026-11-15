/* ============================================================
   SİTE AYARLARI — canlıya almadan önce burayı doldurun
   ============================================================ */
window.SITE_CONFIG = {
  // WhatsApp numarası: ülke koduyla, başında + ve boşluk olmadan. Örn: 905551112233
  whatsappNumber: "90XXXXXXXXXX",

  // Talepler ve olaylar için Google Apps Script web uygulaması adresi (KURULUM.md, 2. adım).
  // Boş bırakılırsa hiçbir şey kaydedilmez (test modu).
  endpoint: "",

  // Fiyatlar TASLAKTIR. Gerçek fiyatlarla değiştirin.
  priceNote: "Tahmini fiyatlar. Kesin fiyat WhatsApp'ta iletilir.",

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
      price: 95000,
      currency: "₺",
      badge: "Orijinal",
    },
    {
      id: "b4-yerli",
      set: "Bayley-4",
      type: "Yerli Üretim",
      title: "Yerli Üretim Set",
      desc: "İçeriğin bir kısmı yerelde, 3D baskı dahil yöntemlerle üretilir. Daha uygun fiyat.",
      price: 35000,
      currency: "₺",
      badge: "Yerli Üretim",
    },
  ],
};
