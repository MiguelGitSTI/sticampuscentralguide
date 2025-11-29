# Cloud Functions: Notification Sender

This function listens to Firestore collection `notifications_outbox` and sends an FCM topic notification for each new document.

Document shape:
- from: string
- topic: string (e.g., MAWD302 or all)
- message: string
- createdAt: serverTimestamp
- createdByUid: string

On success, the doc is updated with:
- status: "sent"
- sentAt: serverTimestamp

On error:
- status: "error"
- error: string

## Deploy

1) Install tools
```
npm install -g firebase-tools
firebase login
```

2) Install function deps
```
cd functions
npm install
```

3) Deploy
```
cd ..
firebase deploy --only functions
```

## Emulators (optional)
```
firebase emulators:start --only firestore,functions
```