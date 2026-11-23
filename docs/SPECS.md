# Product SPECS

สถานะ: Draft · Reference: KoiArt 1.23.3 (47) · ตรวจ artifact 23 พ.ย. 2026

แอปใหม่ทำให้เดสก์ท็อป macOS มีวอลเปเปอร์และเอฟเฟกต์ที่ปรับเองได้ เป้าหมายแรกคือใช้เองแบบ offline และแยกบริการออนไลน์ไว้เพื่อเปิดใช้ภายหลังหากทำเป็นสินค้า ชื่อโปรเจกต์ปัจจุบันเป็นชื่อชั่วคราว

อ่าน [Frontend](frontend/SPECS.md), [Backend](backend/SPECS.md) และ [Research](RESEARCH.md) คำว่า Backend ในเอกสารชุดนี้หมายถึงระบบนอกเครื่อง ส่วน renderer, scheduling, cache และ integration กับ macOS เป็นงานของตัวแอป

| Phase | Features | เกณฑ์วัดผลก่อนผ่าน |
| --- | --- | --- |
| P0 ทดลอง | FE-03 และ FE-05 | ตั้งภาพและแสดง overlay บนจอเดียวได้ ทดสอบการสลับ Space, fullscreen, lock และการปิดแอป |
| P1 ใช้เอง | FE-01 ถึง FE-06 และ FE-11 ส่วน settings/lifecycle | ใช้ฉากและเอฟเฟกต์จาก bundle แบบ offline เลือกฉากและ effect แยกกัน คืนค่าการตั้งค่าหลังเปิดใหม่ และหยุด render ตามสถานะเครื่อง |
| P2 เพิ่มความสามารถในเครื่อง | FE-07 ถึง FE-09 และ FE-11 ส่วน permission, ข่าว/ภาษา และ FE-14 ส่วน Guide | ทดสอบฉากตามกฎ เวลา และหลายจอ จากนั้นเพิ่ม interaction กับพื้นผิว ตัวละคร และ screen saver ตามความเหมาะสม |
| P3 บริการออนไลน์ | BE-01 ถึง BE-08, FE-02 ส่วนดาวน์โหลด, FE-10, FE-12 ถึง FE-14 | เปิด feature ตามบริการที่พร้อม แต่ละบริการแยกปล่อยได้ ต้องมี flow ล้มเหลวและ recovery ที่ทดสอบแล้ว |

## Feature map

| กลุ่ม | Frontend | Backend |
| --- | --- | --- |
| Menu bar, onboarding, tabs | FE-01 | — |
| Catalog, preview, ภาพปกติ/Ultrawide, ดาวน์โหลด | FE-02 | BE-01 |
| ใช้ภาพจริง แยกจอ และจำค่า | FE-03 | — |
| Day/night, season, random, local weather, match effect | FE-04 | BE-02 สำหรับสภาพอากาศภายนอก |
| Snow, rain, lightning, rainbow, leaves, sakura, fireflies, starfall, wind | FE-05 | — |
| Behind windows, pause, frame rate, full screen, multi-display | FE-06 | — |
| Snow accumulation, snowballs, interactive surfaces | FE-07 | — |
| Snowmen, trees, decorations, Santa, Yeti, elves, train, plough | FE-08 | — |
| Screen saver | FE-09 | — |
| Friends, invitations, gifts, notes และ delivery | FE-10 | BE-03 |
| Preferences, permissions, launch at login, news, localization | FE-11 | BE-01 สำหรับข่าวออนไลน์ถ้าต้องการ |
| Commercial license, device management, updates | FE-12 | BE-04, BE-05 |
| Health, privacy และการกู้บริการ | — | BE-06 |
| Item collection, daily rewards และ unlocks | FE-13 | BE-07 |
| Guide, help, wish และ preferences ด้าน privacy | FE-14 | BE-08 |

ตรวจ UI แอปอ้างอิงถึงหน้า Unlock และทบทวนเอกสารสาธารณะแล้ว ดู [หลักฐานและรายการทดสอบหลัง Unlock](RESEARCH.md)

## กติกาข้าม feature
- ตั้งค่า wallpaper, effect และโหมดเลือกอัตโนมัติแยกกัน Auto wallpaper ทำงานเมื่อเปิด match effect เท่านั้นใน P1; โหมดอื่นเพิ่มใน P2 และเลือกได้ทีละโหมด
- เอฟเฟกต์ถูกพักเมื่อมีเหตุ pause ใดเหตุหนึ่ง และกลับมาเมื่อหมดทุกเหตุและผู้ใช้ยังเปิด effect อยู่ การ pause ไม่สลับ wallpaper
- ค่าเริ่มต้นเน้นงานทั่วไป ให้ overlay รับคลิกเฉพาะขณะผู้ใช้เปิดโหมด interaction อย่างชัดเจน
- สื่อภายนอกล้มเหลวให้แสดงฉากเดิมหรือภาพใน bundle การตั้งค่า desktop ของผู้ใช้ต้องไม่หายเมื่อ download หรือ apply ล้มเหลว
- Release gate: เครื่อง Apple Silicon จริง, จอหลัก/จอนอก, unplug/replug, lock/wake, restart, Space/fullscreen, offline และ Reduced Motion Intel และ macOS รุ่นต่ำสุดของแอปใหม่ตัดสินหลัง P0
