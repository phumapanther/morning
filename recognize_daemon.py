# recognize_daemon.py — รันค้างไว้ อ่าน path ไฟล์ wav จาก stdin ทีละบรรทัด พิมพ์ข้อความที่ถอดได้ (บรรทัดว่าง = ฟังไม่ออก)
# ponytail: แทนการ spawn python ใหม่ทุกช่วงเสียง — ประหยัด ~1.5 วิ/รอบ
import sys

import speech_recognition as sr

r = sr.Recognizer()
r.operation_timeout = 10  # กันเน็ตอืดแล้วค้างทั้งลูป

for line in sys.stdin:
    p = line.strip()
    if not p:
        print(flush=True)
        continue
    try:
        with sr.AudioFile(p) as f:
            audio = r.record(f)
        print(r.recognize_google(audio, language="th-TH"), flush=True)
    except Exception:
        print(flush=True)
