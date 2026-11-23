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

## Git Flow และการส่งงาน
- ใช้ `main` เป็นที่เก็บเอกสารของทีม เช่น `AGENTS.md`, สเปก แผนวิจัย และผลทดสอบที่ยืนยันแล้ว แยก document-only commit ให้ตรวจได้ง่าย
- ใช้ `develop` รวมโค้ดที่พร้อมให้ทีมทดสอบ และสร้าง branch งานแอปจาก `develop` ด้วย `git flow feature start <scope>` เช่น `feature/p1-offline-mvp`
- แยก commit ตามงาน เช่น สเปก ฟีเจอร์ การแก้บั๊ก และผลทดสอบ ตรวจ `git status` และ `git diff --cached --check` ก่อน commit
- รวม feature เข้า `develop` เมื่อ build ผ่านและมีผลทดสอบตามขอบเขตของ feature แล้ว ระบุรายการที่ยังต้องตรวจบน macOS จริงไว้ให้ทีมเห็น
- ส่งกติกาและสเปกจาก `main` มายัง branch พัฒนาเมื่อเกี่ยวกับงาน เพื่อให้ทีมใช้ข้อกำหนดล่าสุด เก็บ `main` ไว้สำหรับเอกสารและ release ที่พร้อมเท่านั้น
- งานเริ่มจากสเปกและ Figma ของโปรเจกต์ ใช้ดีไซน์ที่แก้ไขได้และทรัพยากรของเราเอง พิสูจน์ macOS integration ของแต่ละเฟสก่อนขยายขอบเขต
- งานท้องถิ่นให้ commit ได้ตามปกติ เมื่อจะ push หรือทำ release ให้ยึดคำสั่งของเจ้าของโปรเจกต์สำหรับรอบนั้น
- เก็บสเปก Frontend และ Backend แยกกัน ใช้ REA ตรวจเฉพาะแหล่งข้อมูลที่เกี่ยวกับงาน แล้วบันทึกหลักฐานและข้อจำกัดแยกจาก implementation ของเรา
- ขึ้น Figma ก่อนพัฒนาหน้าหลัก ใช้ Impeccable ช่วยเมื่อเหมาะสม ใช้ Figma ในทีม Gun BUATEAN สำหรับโปรเจกต์นี้
