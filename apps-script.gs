/**
 * Google Apps Script — talepleri ve site olaylarını Google Sheets'e yazar.
 * Kurulum için KURULUM.md dosyasına bakın.
 */
function doPost(e) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var d;
  try { d = JSON.parse(e.postData.contents); } catch (err) { return ContentService.createTextOutput("bad"); }

  if (d.type === "lead") {
    var sh = ss.getSheetByName("Talepler") || ss.insertSheet("Talepler");
    if (sh.getLastRow() === 0) sh.appendRow(["Zaman","Ad soyad","Telefon","E-posta","Adet","Setler","Fiyat algısı","Ziyaretçi ID","Referans"]);
    sh.appendRow([d.ts,d.name,d.phone ? "'" + d.phone : "",d.email,d.qty,d.products,d.price_feedback,d.vid,d.ref]);
  } else if (d.type === "event") {
    var ev = ss.getSheetByName("Olaylar") || ss.insertSheet("Olaylar");
    if (ev.getLastRow() === 0) ev.appendRow(["Zaman","Ziyaretçi ID","Olay","Ürün","Detay","Mobil","Referans"]);
    var p = d.params || {};
    ev.appendRow([d.ts,d.vid,d.event,p.product || "",JSON.stringify(p),d.ua_mobile,d.ref]);
  }
  return ContentService.createTextOutput("ok");
}

function doGet() { return ContentService.createTextOutput("çalışıyor"); }
