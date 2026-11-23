# AGENTS.md

## เป้าหมาย
สร้างแอป macOS สำหรับวอลเปเปอร์และเอฟเฟกต์บนเดสก์ท็อป โดยมี UI, artwork, ชื่อ และ implementation ของเราเอง โปรเจกต์ยังอยู่ในช่วงสเปก

## อ่านก่อนแก้
1. [SPECS.md](docs/SPECS.md) เป็นสารบัญ ขอบเขต ลำดับงาน และรายการ feature
2. [Frontend](docs/frontend/SPECS.md) ครอบคลุมตัวแอป macOS รวม UI, renderer, OS integration และ local state
3. [Backend](docs/backend/SPECS.md) ครอบคลุมข้อมูลและสัญญาบริการนอกเครื่อง
4. [หลักฐาน REA](docs/RESEARCH.md) ใช้ตรวจว่าข้ออ้างเกี่ยวกับ KoiArt มาจากอะไร

## วิธีทำงาน
- อ้าง feature ID ในแผนและงาน implementation อัปเดตสเปกก่อนเมื่อเปลี่ยน contract หรือพฤติกรรมที่ผู้ใช้เห็น
- แยก observed, static clue, proposed และ unknown ออกจากกัน ข้อความใน binary อาจเป็น changelog หรือโค้ดที่ไม่ได้เรียกใช้
- รันต้นแบบ macOS สำหรับ wallpaper/overlay ก่อนเพิ่ม feature อื่น ให้ MVP ใช้ได้ offline ด้วย artwork ที่ bundle มา
- เริ่มด้วย SwiftUI + AppKit ตามความจำเป็น ทดสอบ renderer บนเครื่องจริงก่อนตัดสินใจใช้ Metal หลีกเลี่ยง server หรือตัวจัดการสถานะเพิ่มเติมจนมี feature ที่ต้องใช้
- เก็บ artwork ต้นฉบับและหลักฐานสิทธิ์ของแต่ละ asset ห้ามนำ shader, artwork, UI, credentials หรือส่วนประกอบ proprietary ของ KoiArt มาใช้ในแอปนี้
- เก็บความลับใน Keychain และค่า preferences ที่ไม่อ่อนไหวในเครื่อง ตรวจ input ภายนอกก่อนเขียน cache หรือเปลี่ยน state
- ก่อนปิด feature ให้เทียบ acceptance criteria ในสเปก ทดสอบ OS integration บน macOS จริง และระบุสิ่งที่ยังทดสอบไม่ได้
