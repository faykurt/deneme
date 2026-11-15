/**
 * Google Apps Script — talepleri ve site olaylarını Google Sheets'e yazar.
 * Kurulum için KURULUM.md dosyasına bakın.
 */
var NOTIFY_EMAIL = ""; // yeni talepte bildirim gitsin istiyorsanız e-posta yazın

function doPost(e) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var d;
  try { d = JSON.parse(e.postData.contents); } catch (err) { return ContentService.createTextOutput("bad"); }

  if (d.type === "lead") {
    var sh = ss.getSheetByName("Talepler") || ss.insertSheet("Talepler");
    if (sh.getLastRow() === 0) sh.appendRow(["Zaman","Ad soyad","Telefon","E-posta","Meslek","Şehir","Kurum","Adet","Setler","Kurumsal","Fiyat algısı","Not","KVKK","Ziyaretçi ID","Referans"]);
    sh.appendRow([d.ts,d.name,"'" + d.phone,d.email,d.profession,d.city,d.institution,d.qty,d.products,d.corporate,d.price_feedback,d.note,d.kvkk,d.vid,d.ref]);
    if (NOTIFY_EMAIL) MailApp.sendEmail(NOTIFY_EMAIL, "Yeni talep: " + d.name, d.name + " / " + d.phone + "\n" + d.products + "\nMeslek: " + d.profession + "\nAdet: " + d.qty);
  } else if (d.type === "event") {
    var ev = ss.getSheetByName("Olaylar") || ss.insertSheet("Olaylar");
    if (ev.getLastRow() === 0) ev.appendRow(["Zaman","Ziyaretçi ID","Olay","Ürün","Detay","Mobil","Referans"]);
    var p = d.params || {};
    ev.appendRow([d.ts,d.vid,d.event,p.product || "",JSON.stringify(p),d.ua_mobile,d.ref]);
  }
  return ContentService.createTextOutput("ok");
}

function doGet() { return ContentService.createTextOutput("çalışıyor"); }
