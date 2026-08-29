# recognize.py <wav> — ถอดเสียงไทยผ่าน Google, พิมพ์ข้อความ (เงียบ/ฟังไม่ออก = ไม่พิมพ์อะไร)
import sys

import speech_recognition as sr

r = sr.Recognizer()
r.operation_timeout = 10  # กันเน็ตอืดแล้วค้างทั้งลูป
try:
    with sr.AudioFile(sys.argv[1]) as f:
        audio = r.record(f)
    print(r.recognize_google(audio, language="th-TH"))
except Exception:
    pass
