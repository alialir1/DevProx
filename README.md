سورس ستيفن 


استخدام ويب هوك بوت تيليجرام (PHP)

- ضع توكن البوت في متغير البيئة `TELEGRAM_BOT_TOKEN`
- عيّن رابط الويب هوك في متغير البيئة `WEBHOOK_URL` أو مرره كـ `?url=`
- لطلب ضبط الويب هوك:
  - افتح `/set_webhook.php?token=BOT_TOKEN&url=https://YOUR_DOMAIN/webhook.php&secret=SECRET`
- ملف المعالجة: `webhook.php` يستقبل التحديثات ويتحقق من الهيدر السري إن وجد
- دوال المساعدة متوفرة في `telegram_webhook.php` (set/delete/get webhook و sendMessage)
