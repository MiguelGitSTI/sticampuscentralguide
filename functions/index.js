const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

exports.sendQueuedNotification = onDocumentCreated('notifications_outbox/{docId}', async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log('No data in event');
    return;
  }
  const data = snap.data();
  try {
    const from = String(data.from || 'Notice');
    const topic = String(data.topic || '').trim().toLowerCase();
    const message = String(data.message || '').trim();
    if (!topic || !message) {
      console.warn('Missing topic or message');
      return;
    }

    const payload = {
      notification: {
        title: from,
        body: message,
      },
      topic: topic,
    };

    const resp = await getMessaging().send(payload);
    console.log('Sent FCM id:', resp);
    await snap.ref.set({ status: 'sent', sentAt: FieldValue.serverTimestamp() }, { merge: true });
  } catch (err) {
    console.error('FCM send failed', err);
    await snap.ref.set({ status: 'error', error: String(err) }, { merge: true });
  }
});