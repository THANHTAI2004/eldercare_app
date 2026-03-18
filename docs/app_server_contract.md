# App - Server Contract

Tai lieu nay ghi lai contract toi thieu ma app dang su dung cho luong `owner` / `viewer` cua device.

Nguyen tac chung:
- Snake case la contract chinh thuc: `device_id`, `user_id`, `link_role`, `phone_number`, `linked_users`.
- App van giu mot vai fallback parser camelCase de tuong thich nguoc, nhung code moi va UI moi chi duoc dua vao snake case.
- `link_role` hop le trong app hien tai: `owner`, `viewer`.
- Cac endpoint mutate (`claim`, `add viewer`, `remove viewer`) hien chi can HTTP status thanh cong; app khong doc response body de render UI. Duoi day van ghi example body de de chot contract on dinh ve sau.

## 1. POST /api/v1/devices/{device_id}/claim

Muc dich:
- Lien ket device vao tai khoan dang dang nhap.
- Neu thanh cong, app se reload `GET /api/v1/me/devices`.

Request body:

```json
{}
```

Ghi chu:
- App hien tai khong gui body cho endpoint nay.

Success response:

```json
{
  "ok": true,
  "device_id": "dev-esp-001",
  "link_role": "owner"
}
```

Error codes:
- `403`: tai khoan hien tai khong duoc phep claim device nay.
- `404`: khong tim thay `device_id`.
- `409`: device da co owner hoac khong con claim duoc.
- `422`: `device_id` khong hop le.

## 2. POST /api/v1/devices/{device_id}/viewers

Muc dich:
- Owner them mot viewer vao device.

Request body:

```json
{
  "user_id": "viewer-001"
}
```

Ghi chu:
- App da khoa payload theo contract nay.
- App khong gui `phone_number` cho endpoint nay.

Success response:

```json
{
  "ok": true,
  "device_id": "dev-esp-001",
  "user_id": "viewer-001",
  "link_role": "viewer"
}
```

Error codes:
- `403`: caller khong phai owner cua device.
- `404`: khong tim thay device hoac user can them.
- `409`: user da la viewer cua device nay.
- `422`: payload sai format, thieu `user_id`, hoac `user_id` khong hop le.

## 3. DELETE /api/v1/devices/{device_id}/viewers/{user_id}

Muc dich:
- Owner go viewer khoi device.

Request body:

```json
{}
```

Ghi chu:
- App khong gui body cho endpoint nay.

Success response:

```json
{
  "ok": true,
  "device_id": "dev-esp-001",
  "user_id": "viewer-001"
}
```

Error codes:
- `403`: caller khong phai owner cua device.
- `404`: khong tim thay device, user, hoac lien ket viewer can xoa.
- `409`: thao tac xung dot voi rule nghiep vu cua server, neu co.
- `422`: `device_id` hoac `user_id` khong hop le.

## 4. GET /api/v1/me/devices

Muc dich:
- Tra ve danh sach device ma tai khoan hien tai dang duoc lien ket.
- App dung endpoint nay de build danh sach device va xac dinh quyen theo tung device qua `link_role`.

Request body:

```json
{}
```

Success response:

```json
{
  "count": 2,
  "items": [
    {
      "device_id": "dev-esp-001",
      "name": "Phong ngu",
      "user_id": "owner-001",
      "link_role": "owner",
      "linked_users": [
        {
          "user_id": "owner-001",
          "name": "Chu thiet bi",
          "role": "manager",
          "link_role": "owner",
          "phone_number": "0987654321"
        },
        {
          "user_id": "viewer-001",
          "name": "Nguoi nha",
          "role": "viewer",
          "link_role": "viewer",
          "phone_number": "0911222333"
        }
      ]
    },
    {
      "device_id": "dev-esp-002",
      "name": "Phong khach",
      "user_id": "owner-001",
      "link_role": "viewer",
      "linked_users": [
        {
          "user_id": "other-owner-001",
          "name": "Owner khac",
          "role": "manager",
          "link_role": "owner",
          "phone_number": "0900000000"
        },
        {
          "user_id": "owner-001",
          "name": "Tai khoan dang nhap",
          "role": "viewer",
          "link_role": "viewer",
          "phone_number": "0987654321"
        }
      ]
    }
  ]
}
```

Field toi thieu app dang doc:
- `count`
- `items[]`
- `items[].device_id`
- `items[].name`
- `items[].user_id`
- `items[].link_role`
- `items[].linked_users[]`
- `items[].linked_users[].user_id`
- `items[].linked_users[].name`
- `items[].linked_users[].role`
- `items[].linked_users[].link_role`
- `items[].linked_users[].phone_number`

Error codes:
- `401`: chua dang nhap hoac access token het han.
- `403`: session khong duoc phep doc danh sach device.
- `500`: loi server.

## 5. GET /api/v1/devices/{device_id}/linked-users

Muc dich:
- Tra ve danh sach user dang lien ket voi device.
- Man `Quan ly viewer` cua app dung endpoint nay de hien danh sach viewer.

Request body:

```json
{}
```

Success response:

```json
{
  "count": 2,
  "items": [
    {
      "user_id": "owner-001",
      "name": "Chu thiet bi",
      "role": "manager",
      "link_role": "owner",
      "phone_number": "0987654321"
    },
    {
      "user_id": "viewer-001",
      "name": "Nguoi nha",
      "role": "viewer",
      "link_role": "viewer",
      "phone_number": "0911222333"
    }
  ]
}
```

Field toi thieu app dang doc:
- `count`
- `items[]`
- `items[].user_id`
- `items[].name`
- `items[].role`
- `items[].link_role`
- `items[].phone_number`

Error codes:
- `401`: chua dang nhap hoac access token het han.
- `403`: caller khong duoc phep xem danh sach linked users cua device nay.
- `404`: khong tim thay device.
- `500`: loi server.
