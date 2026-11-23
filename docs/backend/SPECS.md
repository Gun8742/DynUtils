# Backend SPECS — optional services

สเปกต่อไปนี้เป็นข้อเสนอของแอปใหม่ ทีมยังไม่ทราบ protocol หรือสถาปัตยกรรมฝั่ง server ของ KoiArt จาก [หลักฐาน REA](../RESEARCH.md) MVP แบบ offline ใช้ bundle และ local settings โดยไม่ต้องมี server เอกสารผู้พัฒนาระบุผู้ให้บริการบางส่วนของ KoiArt (R11) สัญญา API ต่อไปนี้ออกแบบใหม่ เริ่มจาก static hosting และเพิ่ม service/database เมื่อเปิด social หรือ commerce จริง

## BE-01 · Catalog, assets และ release notes · P3 · R3/R4/R5
- Static HTTPS manifest `GET /v1/catalog` รองรับ ETag + 304 และ cache ของ last-known-good. เก็บ media ที่ URL ผูกกับ digest และไม่ overwrite object เดิม
- Catalog manifest มี `schemaVersion`, `revision`, `publishedAt`, `scenes[]`. Scene มี `id`, `titleKey`, `effects[]`, `variants[]`. Variant มี `role` (preview/static/timeFrame), `ratioClass`, `timeSlot?`, `url`, `mime`, `sha256`, `byteLength`, `pixelWidth`, `pixelHeight`. ข่าวเป็น static manifest แยกและ optional
- Publish assets ก่อน manifest ตรวจ schema/digest/ภาพครบทุก variant ที่ประกาศ และ validate identifiers/เวลาให้ไม่ซ้ำกัน ฉากที่ถอนอยู่ได้ในเครื่องจนผู้ใช้เปลี่ยนฉาก
- ผ่านเมื่อ 304 ไม่โหลดซ้ำ manifest schema ใหม่เกินรองรับแล้วยังคงของเก่า และ broken asset หนึ่งตัวไม่ทำให้ catalog ทั้งหมดล่ม

## BE-02 · Outside weather integration · P3 · R3/R5
- อนุญาตให้ client เรียก provider โดยตรงเมื่อเหมาะสม ถ้าต้องซ่อน credential หรือแชร์ quota ใช้ proxy `GET /v1/weather?region=<coarse-region>`
- ตอบ `condition` (clear/cloud/rain/snow/other), `observedAt`, `validUntil`. Normalize response, cache ต่อ coarse region, rate limit, ไม่บันทึกพิกัดละเอียดหรือคำขอต่อบุคคลเป็นประวัติ
- กำหนด freshness จาก validUntil และ recheck หลัง wake แบบจำกัดความถี่ เอกสารอ้างอิงมี cadence ขัดกัน (R12) จึงกำหนดค่าของเราเองและใช้ mock clock ทดสอบ
- Client จับคู่ effect กับ condition ตาม FE-04 เมื่อ 429/503 ให้เคารพ Retry-After ใช้ snapshot จนหมดอายุ แล้วคงฉากล่าสุด
- ผ่านเมื่อ provider ล่มแล้ว UI ยังเปิดได้ region ที่ไม่ถูกต้องได้ 400 และหมดอายุแล้ว client ไม่เปลี่ยนฉากจากข้อมูลเก่า

## BE-03 · Identity, friends, gifts และ inbox · P3 · R3/R5
- ใช้ managed identity หรือ provider ที่ตรวจได้ เก็บ token ฝั่ง macOS ใน Keychain; server map subject เป็น internal user ID ใช้ HTTPS ทุกคำขอ ตรวจเจ้าของและผู้รับในแต่ละ mutation
- จัดการ invite และ friendship ตาม state `pending → accepted/declined/revoked`; block แยกจาก friendship และทำให้ส่งใหม่ไม่ได้ทั้งสองทิศ เก็บ constraint ของคู่ผู้ใช้เพื่อป้องกัน invite/friendship ซ้ำ
- Gift มี `kind: note|snowman|tree`, payload แบบ plain text หรือ IDs ของ assets ที่แอปอนุญาต; ห้ามสื่อ arbitrary upstream, ตรวจขนาดข้อความและถี่ในการส่ง. ค่าเริ่มต้นเสนอข้อความ 500 ตัวอักษรและ payload ไม่เกิน 16 KiB
- Sender ส่งพร้อม Idempotency-Key; uniqueness scope = sender + key; ตรวจและ insert gift กับ idempotency ใน transaction เดียว. response ยืนยันว่าบันทึกแล้ว ผู้รับเห็นผ่าน inbox; animation เป็นพฤติกรรมของ client. ใช้ polling พร้อม cursor ก่อนเพิ่ม push
- Optional: presence ใช้ lastSeen จาก heartbeat และหมดอายุตาม TTL; device-targeted gift ตรวจว่าเครื่องปลายทางอยู่ในสิทธิ์เดียวกันและห้ามเครื่องอื่นรับ. กำหนด acknowledgement หลัง client บันทึก inbox ได้แล้ว และล้างงานค้างตาม retention หรือเมื่อเครื่องถูกถอด
- ผ่านเมื่อผู้ใช้คนอื่นอ่าน gift ไม่ได้ การ block ชนะ request ที่เริ่มหลัง commit block เคย retry ได้ ID เดิมแม้ timeout และ key เดิมกับ body ใหม่ได้ 409

| Method/path | Input | Expected response |
| --- | --- | --- |
| POST /v1/friend-invites | recipientHandle | 201 + invite ID; 409 ถ้ามีรายการที่ขัดกัน |
| POST /v1/friend-invites/{id}/accept | — | 200 + friendship ID; ผู้รับ invite เท่านั้น |
| POST /v1/friend-invites/{id}/decline | — | 204; ผู้รับ invite เท่านั้น |
| DELETE /v1/friend-invites/{id} | — | 204; ผู้ส่ง invite เท่านั้น |
| GET /v1/friends | cursor? | 200 + friends + nextCursor |
| DELETE /v1/friends/{id} | — | 204; เฉพาะสมาชิกของคู่ |
| PUT /v1/blocks/{userId} | — | 204; ส่งซ้ำได้ |
| DELETE /v1/blocks/{userId} | — | 204; การ unblock ไม่สร้าง friendship คืน |
| POST /v1/gifts | recipientId, kind, payload, Idempotency-Key header | 201 + gift ID; retry ได้ผลเดิม |
| GET /v1/inbox | cursor?, limit? | 200 + items + nextCursor; owner เท่านั้น |
| PUT /v1/inbox/{giftId}/read | — | 204; owner เท่านั้น |

## BE-04 · Entitlement และ devices · P3 · R3/R5
- เลือก direct distribution หรือ App Store ก่อนลงมือ หาก direct ใช้ hosted checkout + verified webhook; หาก App Store ออกแบบจาก purchase/restore flow ของ StoreKit. ปล่อย MVP ใช้เองได้โดยไม่มีระบบซื้อ
- สถานะ entitlement `active/expired/revoked`. บันทึก provider event ID กันส่งซ้ำและเช็ก source/state เมื่อลำดับ event ย้อนกัน ห้ามให้ client ตั้ง entitlement เองจากสถานะหน้า checkout
- สำหรับ direct เสนอ `GET /v1/entitlement`, `POST /v1/devices`, `GET /v1/devices`, `DELETE /v1/devices/{id}`. ใช้ random installation ID และจำกัด device ใน transaction. ส่งสิทธิ์ offline แบบตรวจลายเซ็นได้ มี expiry/grace ที่ทีมจะกำหนดหลังเลือกรูปแบบขาย
- Device transfer ทำ challenge แบบใช้ครั้งเดียวและหมดอายุเร็ว แสดงอีเมลแบบปิดบางส่วน จำกัด attempts และถอดสล็อตเดิมพร้อม activate สล็อตใหม่ใน transaction เดียว Upgrade ใช้ verified payment event และคงประวัติ activation
- ผ่านเมื่อซื้อซ้ำ webhook มาช้า ระบบออฟไลน์เกิน grace และมี activation พร้อมกันตอบตรงสถานะจริง การ revoke แสดงหลัง client sync ครั้งถัดไป

## BE-05 · Updates · P3 · R3/R5
- Direct distribution ใช้ static update feed, installer ของเรา และ updater ที่รองรับ signature verification. Feed มี channel, version, build, minOS, artifactURL, size, digest และ metadata ที่ updater ใช้ตรวจลายเซ็น
- โหลดไปพื้นที่ชั่วคราว ตรวจ version, OS, signature และ integrity ก่อนเสนอ install. ใช้ rollout/rollback โดยควบคุม feed และถอน build ที่มีปัญหา เก็บ installer เก่าที่ตรวจได้สำหรับ recovery
- App Store distribution ให้ช่องทางอัปเดตของ Store ดูแล. ผ่านเมื่อ manifest เสีย, installer ถูกแก้, OS ไม่รองรับและปิดหน้าต่างระหว่าง download แล้วเวอร์ชันเดิมยังเปิดได้

## BE-06 · Common contracts, privacy และ operations · P3
- JSON UTF-8, UTC timestamps แบบ RFC 3339, IDs แบบ opaque, cursor ไม่มี PII; error body `{code, message, requestId}` ใช้ 401 สำหรับยังไม่ auth, 403/404 ตาม resource access, 409 conflict, 422 semantic validation, 429 rate limit, 503 upstream unavailable
- Request ID ใช้ trace; log event type/latency/count และ IDs เท่าที่จำเป็น ไม่ log token, ข้อความ gift หรือพิกัดจริง. แยก secrets จาก source และกำหนด retention/deletion ก่อนปล่อย social. เมื่อลบบัญชี revoke session และกำหนดนโยบายว่าของที่ส่งแล้ว anonymize หรือลบ
- เริ่มจาก object storage + CDN สำหรับ static manifests และไฟล์; เมื่อเปิด BE-03/04 ใช้ API เดียวและ PostgreSQL สำหรับ users, invites, friendships, blocks, gifts, entitlements, activations และ idempotency. ค่อยเพิ่ม queue หากมีงาน asynchronous ที่ต้อง retry จริง
- ผ่านเมื่อสำรองและกู้ข้อมูลได้ใน staging, แยก environment และ secret ได้ มี health/error-rate alert และทดสอบ outage โดย FE ยังใช้ wallpaper/effect ในเครื่องได้

## BE-07 · Collections และ daily rewards · P3 · R11
- `GET /v1/collection` คืน item IDs และ revision; `POST /v1/rewards/daily` คืนผล claim ล่าสุดของวัน ก่อนสุ่มจาก pool ของที่ยังไม่มี ใช้วันตาม server และ timezone ที่ตั้งบนบัญชี การเปลี่ยน timezone ไม่เปิดสิทธิ์ย้อนหลัง
- ใช้ unique constraints ที่ owner + reward day และ owner + item ตัดสิน claim ใน transaction; เมื่อ pool หมดคืนสถานะ exhausted. หากมี unlock-all ให้ผูกกับ verified purchase event แยกจาก app entitlement
- ผ่านเมื่อกดพร้อมกันจากหลายเครื่องได้ผลเดิม หลัง reinstall โหลดชุดเดิมได้ และข้อมูล cache เก่าขณะ offline ไม่ทำให้ของเดิมหาย

## BE-08 · Support, feedback และ preferences · P3 · R11
- `POST /v1/support-requests` รับ category (help/wish), ข้อความ, contact email และ attachments ที่ผู้ใช้เลือก กำหนด max bytes/type, rate limit และ idempotency; worker ส่งรายละเอียดให้ support หลังสร้าง ticket สำเร็จ
- `PUT /v1/preferences/marketing` เก็บ opt-in ระดับบัญชี ส่งออกผลไป provider และ retry เมื่อ provider ล่ม. Transactional notices แยกจาก marketing
- ผ่านเมื่อ retry แบบฟอร์มไม่สร้างสอง ticket ไฟล์นอกประเภท/เกินขนาดโดนปฏิเสธ ตรวจ attachment retention ได้ และการ opt-out มีผลข้ามเครื่อง
