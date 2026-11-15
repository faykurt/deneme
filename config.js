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
      id: "b4-3d",
      set: "Bayley-4",
      type: "3D Baskı",
      title: "Bayley-4 Uyumlu 3D Baskı Set",
      desc: "Manipülatifler yerelde 3D baskı ile üretilir. Orijinale göre daha ulaşılabilir fiyat.",
      price: 35000,
      currency: "₺",
      badge: "3D Baskı",
    },
    {
      id: "b3-orijinal",
      set: "Bayley-III",
      type: "Orijinal",
      title: "Bayley-III Orijinal Set",
      desc: "Bayley-III için orijinal set, temin edilebilirlik durumuna göre sağlanır.",
      price: 55000,
      currency: "₺",
      badge: "Orijinal",
    },
    {
      id: "b3-3d",
      set: "Bayley-III",
      type: "3D Baskı",
      title: "Bayley-III Uyumlu 3D Baskı Set",
      desc: "Bayley-III manipülatiflerinin 3D baskı ile üretilmiş karşılığı.",
      price: 25000,
      currency: "₺",
      badge: "3D Baskı",
    },
  ],
};
