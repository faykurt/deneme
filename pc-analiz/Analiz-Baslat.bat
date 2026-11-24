@echo off
chcp 65001 >nul
echo PC Performans Analizi baslatiliyor...
echo (Daha eksiksiz sonuc icin bu dosyaya sag tik ^> Yonetici olarak calistir)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Analiz.ps1" %*
echo.
pause
