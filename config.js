/* ============================================================
   SİTE AYARLARI — canlıya almadan önce burayı doldurun
   ============================================================ */
window.SITE_CONFIG = {
  // Talepler ve olaylar için Google Apps Script web uygulaması adresi (KURULUM.md, 2. adım).
  // Boş bırakılırsa hiçbir şey kaydedilmez (test modu).
  endpoint: "https://script.google.com/macros/s/AKfycbzuLAAl2IJyUFAmP0rYH3q3tkEaXhxcdH8tnd4GG8eiUffaz_sktN4ZqbdQdpvl9OTzsA/exec",

  // Fiyat aralıkları (£). Değiştirmek için priceText alanlarını düzenleyin.
  priceNote: "Fiyatlar tahminidir. Sipariş adetleri netleştikten sonra kesin fiyatlar tarafınıza iletilecektir.",

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
      title: "Bayley-4 Orijinal Set",
      desc: "Yurt dışından temin edilir.",
      priceText: "£1.600 – £1.800",
      badge: "Orijinal",
    },
    {
      id: "b4-yerli",
      set: "Bayley-4",
      type: "Yerli Üretim",
      title: "Bayley-4 Uyumlu Yerli Üretim Set",
      desc: "Orijinal ürün değildir. Orijinal setin ağırlık, boyut ve renk özellikleri eşlenerek birebir ölçülerde üretilir.",
      priceText: "£500 – £600",
      badge: "Yerli Üretim",
    },
  ],
};
