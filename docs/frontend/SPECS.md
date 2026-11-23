# Frontend SPECS — macOS app

ทุกพฤติกรรมต่อไปนี้เป็นสเปกของแอปใหม่ เลข R อ้างถึง [หลักฐาน](../RESEARCH.md) และ P อ้างถึง [phase](../SPECS.md)

## FE-01 · Menu bar, onboarding และ navigation · P1 · R2/R5
- เปิดครั้งแรกจาก menu bar ได้ มี quick actions สำหรับเปิด/หยุดเอฟเฟกต์ เลือก effect ล่าสุด เปิดหน้าหลัก และ Quit
- หน้าหลักแยก Wallpapers, Effects, Settings; เพิ่ม Screen Saver และ Social เมื่อเปิด feature นั้น แต่ละหน้ามี empty, loading และ recovery ตามความจำเป็น
- Onboarding ให้ลองฉากจาก bundle หรือข้ามได้ อธิบาย permission เมื่อผู้ใช้เปิดฟีเจอร์ที่ต้องใช้ หากไอคอนถูกซ่อนยังเปิดหน้าหลักด้วยการเปิดแอปใหม่ได้
- ผ่านเมื่อผู้ใช้ตั้งฉากและ pause ผ่านคีย์บอร์ดได้ เปิดซ้ำแล้วไม่สร้างหน้าต่างซ้ำ และ onboarding ไม่โผล่ทุกครั้ง

## FE-02 · Wallpaper catalog, preview และ asset downloads · P1/P3 · R3/R4/R5
- จดจำ resolution override ต่อ wallpaper และแยกจาก per-display override ของแอปเรา กรณี CDN แบบ offline-first ให้โหลด preview ก่อนและให้ภาพที่ผู้ใช้ขอมีลำดับเหนือ background queue
- Card แสดงชื่อ ภาพ preview โทนหรือ effect ที่เข้ากัน และสถานะสื่อ Preview ไม่เปลี่ยน desktop จนกด Apply
- Resolution: Auto เลือกตามสัดส่วนจอจาก variant ที่มี Normal/Ultrawide เป็น override ถ้าขนาดที่เลือกไม่มี ให้แสดง fallback และคงสัดส่วนภาพด้วยการ crop ตาม anchor ของฉาก
- สถานะ `available → downloading → verifying → ready` หรือ `failed/cancelled` ใช้ progress เมื่อรู้ขนาด รวมคำขอพร้อมกันสำหรับ asset เดียว ตรวจ digest และชนิดไฟล์ก่อนย้ายเข้าที่ ดาวน์โหลดล้มเหลวคงฉากปัจจุบัน
- ผ่านเมื่อ standalone app มีฉาก preview/apply อย่างน้อยหนึ่งฉากในโหมด offline ยกเลิกดาวน์โหลดแล้วกดใหม่ได้ cache เสียแล้วดาวน์โหลดใหม่ได้ และลบ cache แล้วไม่ทำให้ฉากที่ใช้อยู่หาย

## FE-03 · Apply, per-display selection และ restore · P0/P1 · R1/R5
- บันทึก desired scene และ applied scene แยกกัน อ้าง display ID ที่ระบบให้แบบทนการสลับลำดับจอ ใช้ค่า default สำหรับจอใหม่และคืนค่า override เมื่อจอเดิมกลับมา
- เลือก Apply to this display หรือ All displays กรณีสำเร็จบางจอแสดงผลทีละจอพร้อม Retry; ถ้า macOS ปฏิเสธอย่าบันทึกผลลัพธ์ว่า applied
- ใช้ wallpaper integration ที่พิสูจน์ได้บน target macOS ด้วยต้นแบบ วอลเปเปอร์ระบบกับ layer เอฟเฟกต์แยก lifecycle กัน การ quit ต้องปิด layer; ถ้าผู้ใช้เปลี่ยนภาพจาก System Settings ให้เคารพในโหมด manual
- ผ่านเมื่อถอดจอระหว่าง Apply, restart App, sleep/wake และเปลี่ยนภาพจาก System Settings แล้ว state สอดคล้องกับภาพที่แสดง

## FE-04 · Time, season, random, weather และ effect matching · P1/P2 · R3/R5
- โหมด Manual, Match Effect, Season, Random และ Outside Weather เลือกทีละโหมด Manual Apply มีผลทันทีและเปลี่ยนโหมดเป็น Manual หากเลือก Match Effect แล้วไม่มี scene ที่เข้าคู่ ให้คงภาพเดิม
- แยก auto time กับล็อกฉากที่ช่วงเวลาหนึ่ง รองรับแปดช่วงที่อ้างอิงจากตัวอย่างสาธารณะ ตั้งแต่ dawn ถึง night หากมี artwork ครบชุด Day/night เป็นตัวเลือกของฉากที่มีหลายช่วงเวลา ระบบใช้เวลาท้องถิ่นและคำนวณใหม่เมื่อ timezone เปลี่ยนหรือเครื่องตื่น ต้นแบบเริ่มด้วยช่วงเวลาคงที่ก่อนปรับให้เข้ากับดวงอาทิตย์หากจำเป็น
- Season ใช้ hemisphere ที่ผู้ใช้เลือก Random เปลี่ยนตามรอบที่ตั้งและหลีกเลี่ยงภาพซ้ำติดกันเมื่อมีมากกว่าหนึ่งภาพ Outside Weather เปิดเมื่อ BE-02 พร้อมใน P3 และใช้ coarse location ที่ผู้ใช้ยินยอมหรือเลือกเมืองเอง หากข้อมูลเก่าเกินกำหนดให้คงฉากล่าสุด
- ผ่านเมื่อจำลองข้ามเที่ยงคืน เปลี่ยนเขตเวลา ปฏิเสธสิทธิ์ location และสลับโหมดระหว่างโหลดภาพได้ โดยงานเก่าไม่ทับการเลือกใหม่

## FE-05 · Effects, particles และ wind · P0/P1 · R1/R5
- P0 ใช้ effect เดียวเป็นตัวพิสูจน์ desktop layer P1 มี preset Off, Snow, Heavy Snow, Drizzle, Rain, Mist, Leaves, Sakura, Fireflies และ Starfall แยก effect ออกจาก wallpaper
- ใช้ demo เป็นเกณฑ์ P2 ของพื้นผิว: Snow เลื่อนเมื่อหน้าต่างเคลื่อน, Rain กระเซ็น, Sakura เกาะชั่วคราว, Leaves กระจายเมื่อ pointer ผ่าน, Fireflies เข้าหา pointer ที่นิ่ง, Starfall แตกเป็นประกาย ระยะแรกทดสอบแยกจาก effect พื้นฐาน
- Snow เปลี่ยนความหนาแน่นและการตกตาม preset; Rain เปิดปิด lightning/rainbow แยกกันและใช้ค่าเริ่มต้นที่ไม่มี flash; Leaves/Sakura ใช้ drift; Fireflies ใช้ glow/การเคลื่อนไหวช้า; Starfall ใช้ trail ช่วงสั้น
- Density เลือก Light / Balanced / Full ใช้กับทุกเอฟเฟกต์และจำค่าหลังเปิดใหม่ ค่าเริ่มต้น Balanced เพิ่มความชัดของอนุภาคตามพื้นที่จอ มีเพดานต่อจอและลดปริมาณต่อเมื่อเปิด Reduced Motion หรือประหยัดพลังงาน
- Drizzle ใช้หยดฝนสั้นและเบากว่า Rain ส่วน Mist เป็นชั้นหมอกที่ค่อย ๆ เคลื่อนบริเวณขอบล่าง ไม่รับคลิก
- Wind เป็นค่ากลางสำหรับ effect ที่รองรับ มีทิศและความแรง Animation ใช้ delta time จำกัดจำนวน particles และหยุดสร้าง frame เมื่อถูก pause เปิด Reduced Motion ให้ลดการเคลื่อนไหวและงด flash
- ผ่านเมื่อเปลี่ยน effect ซ้ำแล้วไม่มี layer ค้าง ปรับ wind โดยภาพเดสก์ท็อปไม่เปลี่ยน และตั้ง Off แล้ว renderer ไม่ส่ง frame ต่อ

## FE-06 · Placement, performance และ lifecycle · P1/P2 · R1/R5
- มี placement บนเดสก์ท็อปใต้แอปเป็นค่าเริ่มต้น โหมด overlay ด้านหน้าเพิ่มเมื่อทดสอบ ordering และการคลิกผ่านได้ ใช้ display session แยกเพื่อปรับ scale และ frame size
- มี Pause on battery, Pause while gaming/fullscreen ตามสัญญาณที่ platform ยืนยันได้ และ pause เมื่อ lock/asleep ให้แสดงสาเหตุจากชุดเหตุที่ active พร้อมปุ่ม Resume เฉพาะ manual pause
- เสนอ cap 30 FPS เริ่มต้น ก่อนเปิด 60/120 ให้ยืนยัน refresh rate และวัด frame time/energy บนเครื่องจริง ไม่วาดจอที่ offline/asleep และ rebuild เฉพาะจอที่เปลี่ยน
- เก็บ toggle เปิดเอฟเฟกต์รายจอแยกจาก wallpaper และ placement ของ props แยกจากอนุภาค รองรับโหมดลด particle budget เมื่อใช้แบตหรือ Low Power Mode แม้ผู้ใช้ไม่ได้เลือกพักทั้งหมด
- ผ่านเมื่อ lock/unlock, fullscreen/notch, สลับ Space, ลากหน้าต่าง และต่อ/ถอดจอไม่เกิด overlay ค้าง ไม่ขวางคลิก และเมื่อสองสาเหตุ pause ซ้อนกันจะ resume หลังเหตุสุดท้ายจบ

## FE-07 · Snow accumulation, desktop surfaces และ snowballs · P2 · R5
- เริ่มสะสมหิมะที่ขอบล่าง desktop ก่อน ทดลอง Dock, window tops และ widget เป็นรายพื้นผิว เพิ่ม Deeper Snow และโหมด snow ละลายแทนสะสม
- ใช้ bounds และ occlusion เท่าที่ OS ให้ได้ ผูก snow state กับพื้นผิวและจอ ถ้า surface เคลื่อนให้เลื่อน state ตาม ถ้าหายให้ล้าง state ของพื้นผิวนั้น
- ลูกหิมะที่โยนจากเมนูชนพื้นผิวได้ หากอ่าน window geometry ไม่ได้ให้ใช้ขอบล่างเป็น fallback
- ผ่านเมื่อย้าย/ปิดหน้าต่างและเปลี่ยนพื้นที่ Dock แล้วไม่เกิดหิมะลอยค้าง ไม่ทับ menu bar และเมื่อปิด interaction การคลิกแอปอื่นทำงานตามปกติ

- แต่ละเกล็ดเพิ่มความสูงตรงจุดที่ชนก่อน กองที่ชันไหลไปตามความลาดและกระจายไปด้านปลายลม หิมะที่ล้นขอบหน้าต่างหรือ Dock ตกต่อไปยังพื้นผิวด้านล่าง
- ขยับ cursor ผ่านกองเพื่อปัดหิมะไปในทิศที่ลาก ใช้ตำแหน่งเมาส์โดยไม่รับคลิกและไม่ดัก input การวาง cursor ค้างไม่ทำให้กองไหลเพิ่ม

- เปิดโหมดปั้นลูกหิมะในหน้า Effects เพื่อกดเมาส์ซ้ายค้างแล้วลากผ่านกอง ใช้เนื้อหิมะจากกองจริง ลูกจะโตตามปริมาณที่เก็บ ปล่อยเพื่อวางบนพื้นหรือขอบหน้าต่าง คลิกแล้วลากลูกเดิมเพื่อย้ายหรือเก็บหิมะเพิ่ม โหมดนี้เปิดปิดได้และคลิกยังส่งไปยังแอปด้านล่าง
- วางลูกหิมะซ้อนครบสามลูกเพื่อสร้างและบันทึกตุ๊กตาหิมะประจำจอในตำแหน่งนั้น ใช้ Undo ของ Decorations ย้อนการจัดวางได้ ลูกที่ปั้นค้างไว้จะถูกล้างเมื่อปิดโหมดหรือหยุดเอฟเฟกต์

## FE-08 · Seasonal objects, characters และ events · P2 · R5
- ตุ๊กตาหิมะที่บันทึกประจำจอเกิดจากการซ้อนลูกหิมะสามลูก ไม่มีสวิตช์สร้างตุ๊กตาใน Settings เมื่อสร้างแล้วสามารถย้าย หมุน หรือลบและ Undo ได้
- เปิดต้นสนจาก Settings ได้ ต้นสนเลื่อนซ้ายขวา เอน และเปิดปิดไฟได้ ฐานลำต้นชิดขอบล่างของพื้นที่ใช้งานของจอ แม้มีตำแหน่งแนวตั้งที่บันทึกไว้จากเวอร์ชันก่อน
- Santa แสดงการเดินทางและของขวัญ local, Elves ช่วยสร้าง snowman, Yeti และ snowman fights เป็น optional events, Snowplough เคลียร์กอง, Train เป็น visitor local และเป็นภาพประกอบการรับ gift ใน P3
- เปิด/ปิด event แยกชนิด มี trigger อัตโนมัติตาม cooldown หรือเรียกเองจาก menu เมื่อกำหนดให้วิ่งหลายจอใช้ลำดับจอตามตำแหน่ง มิฉะนั้นใช้จอหลัก จำกัดจำนวน visitor พร้อมกัน; ส่ง gift ระยะไกลเป็น FE-10
- ผ่านเมื่อปิดทุก event ได้ ตัวละครไม่เกิดซ้ำหลัง wake และการถอดจอหรือปิด effect ล้าง animation โดยไม่ลบวัตถุที่บันทึก

## FE-09 · Screen saver · P2 · R3/R4/R5
- มีรายการฉาก ปุ่ม preview ปุ่มเริ่ม และวิธีตั้งค่าระบบเมื่อทำได้ Preview ปิดด้วย Escape และคืนการโฟกัสให้หน้าต่างก่อนหน้า
- โหมดหลักเป็น app-managed idle overlay ทุกจอพร้อมฉากจาก bundle เลือก timeout 1/2/5/10/15/30 นาทีและโหมดสลับภาพ ออกเมื่อมี input และหยุดเมื่อระบบ lock/sleep หรือมี video/call/game ตามสัญญาณที่ยืนยันได้
- ให้แจ้งเมื่อ macOS saver/sleep ตั้งเวลาเร็วกว่าส่วนของแอปพร้อมทางไป System Settings และให้ macOS ดูแลการล็อกหน้าจอ
- ผ่านเมื่อ preview ปิดได้ทุกจอ ไม่ปิดกั้น lock screen และไม่เริ่มวาดต่อหลังออก

## FE-10 · Friends, notes และส่งของผ่าน train · P3 · R3/R5
- ลงชื่อเข้าใช้ผ่าน backend ของเรา เพิ่มเพื่อนด้วย invite/confirm และมี decline, remove, block ส่ง snowman/tree ที่ประกอบจาก IDs ของเรา หรือ note แบบ plain text
- แสดง sending, delivered, retryable failure และ rejected ระบุตัวผู้รับก่อนส่ง ใช้ draft local และ request key เดิมเมื่อ retry Inbox อยู่ได้เมื่อ animation ปิดและไม่ต้องรอให้หิมะตกเพื่อเปิดอ่าน
- หากเปิดการส่งข้ามเครื่องในสิทธิ์เดียวกัน ให้แยกรายชื่ออุปกรณ์จากรายชื่อเพื่อน ระบุเครื่องปลายทางและแยกสถานะว่า server รับแล้วหรือเครื่องรับแล้ว
- ผ่านเมื่อส่งซ้ำหลัง timeout ได้ inbox item เดียว ผู้ส่งไม่มีสิทธิ์ส่งให้ blocked recipient ผู้รับอ่านได้หลังเปิดแอปใหม่ และ offline ยังเปิดฉากเดิมได้

## FE-11 · Preferences, permissions, lifecycle, localization และ news · P1/P2 · R2/R5
- ตั้ง startup, placement, pause, frame limit, display, locale และ motion ใน Settings เก็บแบบ versioned ในเครื่อง ขอ permission ตาม feature และอัปเดตสถานะเมื่อผู้ใช้กลับจาก System Settings
- หากไม่ให้สิทธิ์ ให้แสดงขอบเขตที่ยังใช้ได้และทางเปิด settings; launch at login ใช้กลไกของ macOS ที่ยืนยันผ่าน P0/P1 และสะท้อนสถานะจริง
- เลือก English หรือไทยใน Settings ได้ ค่าเริ่มต้นเป็น English รวมถึงค่าตามระบบจากเวอร์ชันก่อน เก็บภาษาที่ผู้ใช้เลือกไว้และใช้ English เป็น fallback สำหรับข้อความที่ยังไม่มีคำแปล รองรับ VoiceOver, focus และ contrast. ข่าวเป็นรายการ release notes ของเรา เก็บ seen state แบบ local
- ผ่านเมื่อ reset settings แล้วกลับค่า default, migration รองรับค่ารุ่นก่อน และสลับภาษาแล้ว label/layout ยังใช้งานได้

## FE-12 · License, devices และ updates · P3 · R3/R5
- แสดงสถานะ entitlement และ last verified แบบอ่านง่าย เมื่อต้องการซื้อให้เปิดช่องทางของเรา รองรับ Restore/Activate และ feedback สำหรับ offline grace, device limit และ revoked state
- ลบอุปกรณ์จากบัญชีผ่าน explicit confirmation ทำ refresh หลัง activation; อัปเดตสถานะ CHECK → DOWNLOAD → VERIFY → INSTALL พร้อม Cancel ก่อนติดตั้ง และ fallback เป็นลิงก์ installer ของเรา
- เมื่อสล็อตเต็มให้แสดงอุปกรณ์และ last active แบบอ่านง่าย ยืนยันตัวตนก่อนย้ายสิทธิ์ไปเครื่องใหม่; ระบุแผนสิทธิ์ แยก upgrade จาก transfer และมีทางกู้ key ผ่านผู้ให้บริการ
- ผ่านเมื่อ timeout หรืออัปเดตเสียยังเปิดเวอร์ชันเดิมได้ ปิดหน้าซื้อแล้วค่า desktop ไม่หาย และการเปลี่ยนสถานะ entitlement ไม่ทำให้แอป render ค้าง

## FE-13 · Item collection และ rewards · P3 · R11
- แยกของตกแต่งพื้นฐานที่ใช้ได้ offline กับของที่ปลดล็อกผ่านการเล่นหรือ entitlement. แสดงสถานะ available/locked/new และอธิบายทางได้มาบน card โดยไม่สร้างรายการซ้ำเมื่อรางวัลมาช้า
- ถ้าเปิด daily reward ให้ reset ตาม timezone ของบัญชีและ sync ข้ามเครื่อง เก็บรายการที่ได้ล่าสุดในเครื่องให้ใช้ของที่มีอยู่ได้แม้ offline. การซื้อของตกแต่งทั้งหมดเป็นตัวเลือกทางผลิตภัณฑ์แยกจากแอปหลัก
- ผ่านเมื่อกดรับพร้อมกันจากสองเครื่องได้ของชิ้นเดียว การเปลี่ยนเวลาเครื่องไม่ทำให้รับซ้ำ และของที่เคยแต่งยังแสดงเมื่อไม่มีเครือข่าย

## FE-14 · Guide, feedback, support และ privacy controls · P2/P3 · R7/R11
- ให้เปิด Guide ย้อนดู demo ความสามารถได้หลัง onboarding พร้อมปุ่มปิด demo และคืนค่าเอฟเฟกต์ก่อนหน้าเมื่อจบ
- P3 ให้เปิด Help / Make a wish เป็นแบบฟอร์มของเรา แสดงตัวอย่างข้อความกับภาพแนบก่อนส่ง ให้ลบแต่ละภาพได้ และส่งต่อเมื่อกดยืนยันจากหน้าแบบฟอร์ม สำเร็จแล้วแสดงหมายเลขอ้างอิง
- แยก marketing opt-in จากข้อความเกี่ยวกับสิทธิ์และรายการซื้อ ถ้ามี optional diagnostics ให้ดูรายการข้อมูลและปิดได้จาก Settings ไม่มีการบันทึก click stream หรือภาพหน้าจออัตโนมัติเป็นค่าเริ่มต้น
- ผ่านเมื่อปิดหรือส่งแบบฟอร์มไม่สำเร็จแล้วเก็บ draft ใน session, ไม่มีภาพแนบหลังผู้ใช้เอาออก และการปิด diagnostics มีผลกับ event ถัดไป

## Local state และ implementation boundaries
- `Preferences`: schemaVersion, placement, pause flags, performance, locale, chosenRule, selectedEffect. `DisplaySelection`: displayID, desiredSceneID, lastAppliedSceneID, resolution. `AssetCache`: digest → local path/bytes/lastUsed พร้อม pin ของที่ใช้อยู่
- ให้ Coordinator resolve วัน/สภาพเครื่อง → selection → renderer โดย cancel งานเก่าเมื่อ selection เปลี่ยน AppKit adapter ดูแล desktop, window และจอ แยกจาก SwiftUI view state; renderer และ cache ไม่มี dependency กับ Social/Commerce
- ทดสอบ rule resolver ด้วยเวลา/สภาพเครื่องจำลอง ทดสอบ cache cancellation/migration และทำ manual matrix ตาม [Product SPECS](../SPECS.md)
