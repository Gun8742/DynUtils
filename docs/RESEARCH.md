# KoiArt reference research

## Artifact และระดับหลักฐาน
ตรวจตัวติดตั้งในเครื่องที่ `/Applications/KoiArt.app` แบบ static โดยใช้ REA และตรวจ bundled metadata เพิ่มเติม วันที่ 23 พ.ย. 2026

| ID | ระดับ | หลักฐาน |
| --- | --- | --- |
| R1 | Observed | REA inspect_macho: universal x86_64/arm64, โหลด SwiftUI, AppKit, Metal, QuartzCore; พบ imports เช่น display UUID, display asleep และ CAMetalDisplayLink. Evidence `ev_63c6ae4727866c66c0dd7cb66b267afa2d05372ad696e01eb54f01da4b931e12` |
| R2 | Observed | REA inspect_plist: KoiArt 1.23.3 build 47, macOS ≥ 14, LSUIElement=true. Evidence `ev_d2c532a62601ad2a732721e6e9755eb1f5f1174c9b985ba6c8b37139957ee0da` |
| R3 | Observed / clue | REA demangle_swift คืนชื่อ WallpaperStore, WeatherWatch, Friends, License, Updates, ScreenSaver. ชื่อยืนยันว่าพบสัญลักษณ์อ้างอิงกลุ่มนี้ การเรียกใช้และหน้าที่ภายในยังต้องตรวจเพิ่ม. Evidence `ev_1537d0645c6552067a654df9d75ced81b2bc8248b3be969f93d71f863f1526d6` |
| R4 | Observed | `Contents/Resources/wallpapers.json` มี 9 items และทุก item มี id, weather, files พร้อม picture, normalPicture, daylong และ normalDaylong. Bundle มี HEIC previews สำหรับวอลเปเปอร์และ screen saver |
| R5 | Static clue | ข้อความภาษาอังกฤษและชื่อสัญลักษณ์จาก executable บอกถึง Behind windows, pause on battery/gaming, resolution Auto/Normal/Ultrawide, match effect/time, snow surfaces, seasonal props, train gifts, update retry และ license/device UI. ข้อความบางส่วนเป็น changelog |
| R6 | Unknown | Ghidra ไม่ได้ตั้ง GHIDRA_INSTALL_DIR และ REA ไม่พบ Hopper launcher จึงยังไม่มีผล decompile ผัง function หรือ runtime trace ส่วน flow หลัง Unlock ติด license gate |

## ตรวจแอปจริงและเอกสารผู้พัฒนา

| ID | ระดับ | หลักฐาน |
| --- | --- | --- |
| R7 | UI observed | เปิด KoiArt → Welcome → Show me → 6 หน้า demo (Snow, Rain, Sakura, Leaves, Fireflies, Starfall) → ตัวอย่างวอลเปเปอร์ 9 ฉาก → ตกแต่ง snowman/tree → ส่งของ → Yeti → ของขวัญ Santa → ซื้อหรือกรอก license key. หน้า Unlock ปิดปุ่มไว้เมื่อช่อง key ว่าง และไม่พบปุ่มข้ามที่หน้านี้ |
| R8 | UI describes behavior | ข้อความใน demo อธิบายหิมะเลื่อนหล่นเมื่อขยับหน้าต่าง ฝนกระเซ็นบนขอบหน้าต่าง กลีบพักบนพื้นผิว ใบไม้กระจายเมื่อชี้ผ่าน หิ่งห้อยเข้าหา pointer ที่หยุดนิ่ง และดาวแตกเป็นประกายเมื่อกระทบหน้าต่าง ตรวจป้ายกำกับครบทั้งหก รายละเอียดฟิสิกส์ยังไม่ได้วัด |
| R9 | Vendor documented | [Product](https://koiart.app/) อธิบาย Apply ทุกจอ, day/night และเลือกเวลาคงที่; [Behind windows](https://koiart.app/blog/snow-behind-windows-mac) ระบุ placement ของ weather/props แยกกัน, Keep windows clear, Click-through และเปิดปิด weather รายจอ |
| R10 | Vendor documented | [Screen Saver](https://koiart.app/blog/christmas-screensaver-mac) อธิบาย 4 ภาพ, idle 1/2/5/10/15/30 นาที, ตัวอย่างทันที, สลับภาพ, fullscreen ทุกจอ และผลเมื่อ macOS เริ่ม screen saver หรือ sleep ก่อน |
| R11 | Vendor documented | [Privacy](https://koiart.app/privacy) ระบุ behavior ของ catalog downloads, weather, license/device transfer, item unlocks, Friends, same-key trains, support/wish, marketing preference และ telemetry. เป็นคำอธิบายจากผู้พัฒนา ยังไม่ได้ trace traffic หรือทดสอบบริการจริง |
| R12 | Conflicting documentation | [บทความ Rain](https://koiart.app/blog/rain-on-mac-desktop) ระบุรอบเช็ก weather 3 ชั่วโมง ขณะที่ privacy ระบุทุกชั่วโมงและตอนเปิด/ตื่น ค่า runtime ของ build นี้จึงยังไม่ยืนยัน |

### รายการที่เหลือหลัง Unlock
1. Inventory ทุกเมนูและ submenu ของไอคอน menu bar แล้วเทียบ FE-01/05/06/08
2. เปิดทุก tab แล้วตรวจ labels/defaults, empty และ error states: Wallpapers, Effects, Screen Saver, Friends, Settings และ Guide/What's New หากเปิดจากเมนูได้
3. ทดสอบ per-display, placement, sleep/fullscreen, power และ screen saver บนเครื่องจริงด้วยการควบคุมสถานะเครื่อง
4. ตรวจ Friends/invite, gift/notes, shared-license devices, item rewards, support และ lifecycle ของ key ด้วยบัญชีและเครื่องทดสอบที่ได้รับอนุญาต การซื้อ/ส่งข้อความจริงแยกจากการดูหน้าจอ
5. ตรวจ update/downloading ด้วย test setup ที่เปลี่ยนเวอร์ชันได้ และทำหลักฐาน per flow. สัญญา API ภายในของ KoiArt ยังไม่ทราบ

SHA-256 ของ executable ที่ REA เปิด: `27962cf93f74ec7c8d1a4badc61c763a0eedffcfb69e9a558d245bcb035f1350`

| Feature family | Evidence | ยังต้องยืนยัน |
| --- | --- | --- |
| Menu bar / settings | R2, R5, R7, R9 | เมนูและหน้าจอจริง ค่า default ของแต่ละ build |
| Wallpaper / catalog | R3, R4, R5, R7, R9, R11 | วิธีเลือก variant, handling หลายจอและการเปลี่ยนตามเวลา |
| Weather / particles | R1, R3, R5, R7, R8, R11, R12 | สูตรจัดกลุ่ม weather, cadence, graphics pipeline, ตัวเลือกต่อ effect |
| Power / window integration | R1, R5, R9 | เกณฑ์ gaming, floating window order, pause priority, สิทธิ์ที่ต้องใช้จริง |
| Props / snow surfaces | R5, R7, R8, R9, R11 | hitbox, interaction, event frequency, ผลของการสลับจอ |
| Screen saver | R3, R4, R5, R10 | ทดสอบ timer, wake และ input จริง |
| Friends / license / updates | R3, R5, R7, R11 | ทดสอบ activation, device transfer, delivery, wire protocol และ update |

## การใช้หลักฐานใน implementation
Frontend และ Backend เป็นพฤติกรรมและ contract ที่เสนอสำหรับแอปใหม่ จึงอาจตั้งค่าเริ่มต้นหรือกติกาต่างจากตัวอ้างอิง งานยืนยันลำดับถัดไปคือสังเกต UI หลัง Unlock ตาม feature ID และทดสอบ wallpaper/overlay บน macOS จริงก่อนลงรายละเอียด renderer. สิ่งที่อยู่ใน executable ไม่รับประกันว่าครอบคลุมฟีเจอร์ทั้งหมดที่เปิดใช้ได้ในแต่ละสถานะหรือแต่ละภูมิภาค
