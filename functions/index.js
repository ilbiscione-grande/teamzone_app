// Behåll detta för att komma åt Auth, Messaging osv.
const admin = require('firebase-admin');
// Lägg gärna import av getFirestore efter admin
const { getFirestore } = require('firebase-admin/firestore');

const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
// v2-HTTPS (onCall)
const { onCall, HttpsError } = require('firebase-functions/v2/https');
// v2‐trigger för dokument‐skapande
// V1‐API (för andra triggers om du behöver)
const functions = require('firebase-functions');
const SibApiV3Sdk = require('sib-api-v3-sdk');

admin.initializeApp();

// BREVO (Sendinblue) API‐nyckel
const BREVO_KEY = process.env.BREVO_API_KEY;
if (BREVO_KEY) {
  const client = SibApiV3Sdk.ApiClient.instance;
  const apiKey = client.authentications['api-key'];
  apiKey.apiKey = BREVO_KEY;
}
const emailApi = new SibApiV3Sdk.TransactionalEmailsApi();

// Hjälp-funktion för att få rätt Firestore-instans
function getDb() {
  // Hämta den namngivna databasen 'region1' i din app
  return getFirestore('region1');
}

// ─── Skicka inbjudningsmail ───────────────────────────────────────────────
exports.sendInvitationEmail = onCall(
  {
    region: 'us-central1',
    secrets: ['BREVO_API_KEY'],
    invoker: ['public'],
  },
  async (req) => {
    const { email, name, teamName, inviteCode } = req.data || {};
    if (!email || !name || !teamName || !inviteCode) {
      throw new HttpsError('invalid-argument',
        'email, name, teamName och inviteCode måste skickas med');
    }

    const emailData = {
      to: [{ email, name }],
      sender: {
        email: 'teamzone.mobileapp@gmail.com',
        name: 'TeamZone',
      },
      subject: `Inbjudan till lag ${teamName}`,
      htmlContent: `
        <p>Hej ${name}!</p>
        <p>Du har blivit inbjuden till lag <strong>${teamName}</strong> i appen TeamZone.</p>
        <p>Klicka på länken för att bli en del av laget: 
           https://teamzoneapp.netlify.app/invite?code=${inviteCode}</p>
      `,
    };

    try {
      await emailApi.sendTransacEmail(emailData);
      return { success: true };
    } catch (err) {
      console.error('📧 Brevo error:', err?.response?.body || err);
      throw new HttpsError('internal', 'Misslyckades skicka inbjudan');
    }
  }
);

// ─── Acceptera pending join‐request ────────────────────────────────────────
exports.acceptPendingRequest = onCall(
  { region: 'us-central1' },
  async (req) => {
    const { requestId } = req.data || {};
    if (!requestId) {
      throw new HttpsError('invalid-argument', 'requestId saknas');
    }

    const db = getDb();
    const reqRef = db.collection('join_requests').doc(requestId);
    const reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw new HttpsError('not-found', `Request ${requestId} saknas`);
    }
    const pending = reqSnap.data();
    const oldUserId   = pending.userId;
    const email       = pending.email;
    const displayName = pending.namn;
    const tempPassword = 'Välkommen123!';

    // Hämta gamla användardata
    const oldUserRef  = db.collection('users').doc(oldUserId);
    const oldUserSnap = await oldUserRef.get();
    const oldData     = oldUserSnap.exists ? oldUserSnap.data() : {};

    // Skapa nytt Auth‐konto
    const userRecord = await admin.auth().createUser({
      email,
      password: tempPassword,
      displayName,
    });
    const newUid = userRecord.uid;

    // Batched writes
    const batch = db.batch();
    batch.delete(reqRef);
    batch.delete(oldUserRef);
    const newUserRef = db.collection('users').doc(newUid);
    batch.set(newUserRef, {
      ...oldData,
      uid:        newUid,
      email,
      displayName,
      activated:  true,
    });
    await batch.commit();

    return { uid: newUid };
  }
);


// ─── Push‐notification vid ny kallelse (data-only + wakelock) ────────────
exports.sendCallupNotification = onDocumentCreated(
  {
    database: 'region1',
    document: 'callups/{callupId}',
    region:   'europe-west1',
  },
  async (event) => {
    console.log('▶ sendCallupNotification: start');

    // ── Läs param & kallelse ────────────────────────────────────────────
    const callupId = event.params.callupId;
    console.log(`   callupId = ${callupId}`);
    const callupSnap = event.data;
    if (!callupSnap.exists) {
      console.warn('   ❌ callup-dokumentet finns inte');
      return;
    }
    const callup = callupSnap.data();
    console.log('   callup-data:', callup);

    const userId  = callup.userId;
    const eventId = callup.eventId;
    if (!userId || !eventId) {
      console.warn('   ❌ Avbryter: saknar userId eller eventId');
      return;
    }

    // ── Hämta FCM‐token ───────────────────────────────────────────────────
    console.log(`   Hämtar fcmToken för user ${userId}`);
    const userDoc = await getDb().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.warn(`   ❌ Ingen user-doc för ${userId}`);
      return;
    }
    const fcmToken = userDoc.get('fcmToken');
    console.log(`   fcmToken = ${fcmToken}`);
    if (!fcmToken) {
      console.warn('   ❌ Avbryter: inget fcmToken');
      return;
    }

    // ── Hämta event‐info ───────────────────────────────────────────────────
    console.log(`   Hämtar event-info för event ${eventId}`);
    const evDoc = await getDb().collection('events').doc(eventId).get();
    if (!evDoc.exists) {
      console.warn(`   ❌ Ingen event-doc för ${eventId}`);
      return;
    }
    const ev = evDoc.data() || {};
    console.log('   event-data:', ev);

    // ── Formatera datum & tid ─────────────────────────────────────────────
    const ts = ev.eventDate || ev.start;
    const startDate = ts?.toDate?.();
    if (!startDate) {
      console.warn('   ❌ Ogiltigt startdatum');
      return;
    }
    const dateFormatter = new Intl.DateTimeFormat('sv-SE', {
      month: 'short',
      day:   '2-digit',
      timeZone: 'Europe/Stockholm'
    });
    const timeFormatter = new Intl.DateTimeFormat('sv-SE', {
      hour:   '2-digit',
      minute: '2-digit',
      hour12: false,
      timeZone: 'Europe/Stockholm'
    });
    const formattedDate = dateFormatter.format(startDate);
    const formattedTime = timeFormatter.format(startDate);
    console.log(`   formattedDate=${formattedDate}, formattedTime=${formattedTime}`);

    // ── Bygg title & body ─────────────────────────────────────────────────
    const eventType  = ev.eventType   || 'Evenemang';
    const opponent   = ev.opponent    || '';
    const homeOrAway = ev.isHome ? 'hemma' : 'borta';
    const area       = ev.area        || '';
    const pitch      = ev.pitch       || '';
    const title = `Du är kallad till ${eventType}`;
    const body  = eventType === 'Match'
      ? `${formattedDate} ${formattedTime} – ${opponent} (${homeOrAway})`
      : `${formattedDate} ${formattedTime} – ${area}/${pitch}`;
    console.log(`   title="${title}", body="${body}"`);

    // ── Skicka data‐only message ───────────────────────────────────────────
    try {
      const resp = await admin.messaging().send({
        token: fcmToken,
        android: { priority: 'high' },
        apns: {
          headers: {
            'apns-push-type': 'background',
            'apns-priority':  '5'
          },
          payload: {
            aps: { 'content-available': 1 }
          }
        },
        data: {
          title,
          body,
          callupId,
          eventType,
          eventDate: formattedDate,
          eventTime: formattedTime,
          opponent,
          homeOrAway,
          area,
          pitch,
        }
      });
      console.log('   ✅ send() response:', resp);
    } catch (err) {
      console.error('   ❌ Fel vid admin.messaging().send():', err);
    }
  }
);


// ─── Push‐notification vid påminnelse ─────────────────────────────────────
exports.sendReminderNotification = onDocumentUpdated(
  {
    database: 'region1',
    document: 'callups/{callupId}',
    region:   'europe-west1',
  },
  async (event) => {
    console.log('▶ sendReminderNotification: start');

    // Hämta fält före/efter
    const beforeData = event.data.before.data() || {};
    const afterData  = event.data.after.data()  || {};
    const beforeTs   = beforeData.lastReminderAt;
    const afterTs    = afterData.lastReminderAt;
    const beforeMs   = beforeTs ? beforeTs.toMillis() : null;
    const afterMs    = afterTs  ? afterTs.toMillis()  : null;

    // Skip om inget eller samma timestamp
    if (afterMs === null || beforeMs === afterMs) {
      console.log('   lastReminderAt ej ändrat – skip');
      return;
    }

    const callupId = event.params.callupId;
    console.log(`   callupId = ${callupId}`);
    const callup   = afterData;
    const userId   = callup.userId;
    const eventId  = callup.eventId;
    if (!userId || !eventId) {
      console.warn('   ❌ Saknar userId eller eventId – skip');
      return;
    }

    // Hämta token, event‐info, formatera datum/tid (samma som ovan)…
    const userDoc = await getDb().collection('users').doc(userId).get();
    const fcmToken = userDoc.get('fcmToken');
    if (!fcmToken) {
      console.warn('   ❌ Ingen fcmToken – skip');
      return;
    }
    const evDoc = await getDb().collection('events').doc(eventId).get();
    const ev     = evDoc.data() || {};
    const tsEv   = ev.eventDate || ev.start;
    const startDate = tsEv?.toDate?.();
    if (!startDate) {
      console.warn('   ❌ Ogiltigt startdatum – skip');
      return;
    }
    const dateF = new Intl.DateTimeFormat('sv-SE', {
      month: 'short', day: '2-digit', timeZone: 'Europe/Stockholm'
    });
    const timeF = new Intl.DateTimeFormat('sv-SE', {
      hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'Europe/Stockholm'
    });
    const formattedDate = dateF.format(startDate);
    const formattedTime = timeF.format(startDate);

    // Bygg titel/body för påminnelse
    const eventType  = ev.eventType   || 'Evenemang';
    const opponent   = ev.opponent    || '';
    const homeAway   = ev.isHome      ? 'hemma' : 'borta';
    const area       = ev.area        || '';
    const pitch      = ev.pitch       || '';
    const title = `Påminnelse! Du är kallad till ${eventType}`;
    const body  = eventType === 'Match'
      ? `${formattedDate} ${formattedTime} – ${opponent} (${homeAway})`
      : `${formattedDate} ${formattedTime} – ${area}/${pitch}`;

    // Skicka system‐notification + data
    try {
      await admin.messaging().send({
        token: fcmToken,
        android: {
          priority: 'high',
          notification: { title, body }
        },
        apns: {
          headers: {
            'apns-push-type': 'alert',
            'apns-priority':  '10'
          },
          payload: {
            aps: {
              alert: { title, body },
              badge: 1
            }
          }
        },
        data: {
          callupId,
          eventType,
          eventDate:  formattedDate,
          eventTime:  formattedTime,
          opponent,
          homeOrAway: homeAway,
          area,
          pitch,
          reminder: 'true'
        }
      });
      console.log('   ✅ sendReminderNotification sent');
    } catch (err) {
      console.error('   ❌ Fel vid admin.messaging().send():', err);
    }
  }
);

// ─── Hjälpfunktion för att räkna ut seasonId ──────────────────────────────
function computeSeasonId(date, crossYear, startMonth) {
  const year = date.getFullYear();
  if (!crossYear) {
    return `${year}`;
  }
  // JS månadsindex är 0–11, men vi vill jämföra 1–12:
  const month = date.getMonth() + 1;
  if (month >= startMonth) {
    return `${year}_${year + 1}`;
  } else {
    return `${year - 1}_${year}`;
  }
}

// ─── Uppdatera playerStats när callup-status ändras ──────────────────────
exports.onCallupStatusChanged = onDocumentUpdated(
  {
    database: 'region1',
    document: 'callups/{callupId}',
    region:   'europe-west1',
  },
  async (event) => {
    const before = event.data.before.data() || {};
    const after  = event.data.after.data()  || {};
    // Hoppa om status inte ändrats
    if (before.status === after.status) return;

    const oldStatus = before.status;
    const newStatus = after.status;
    const callupId  = event.params.callupId;
    const userId    = after.memberId || after.userId;    // beroende på ditt fält
    const eventId   = after.eventId;
    if (!userId || !eventId) return;

    const db = getDb();

    // 1) Hämta eventet för att avgöra typ, datum, team och season
    const evSnap = await db.collection('events').doc(eventId).get();
    if (!evSnap.exists) return;
    const ev      = evSnap.data();
    const rawType = (ev.eventType || '').toLowerCase();
    const isMatch    = rawType === 'match';
    const isTraining = rawType === 'träning';
    const date       = (ev.eventDate || ev.start)?.toDate() || new Date();

    // 2) Hämta lagets season‐inställningar
    const teamId    = ev.teamId;
    const teamSnap  = await db.collection('teams').doc(teamId).get();
    const crossYear = teamSnap.data()?.seasonCrossYear    || false;
    const startMo   = teamSnap.data()?.seasonStartMonth   || 1;
    const season    = computeSeasonId(date, crossYear, startMo);

    // 3) Bygg dina delta‐värden:
    //   – callupsFor… räknas redan när du skickar kallelsen, så vi hoppar dem här
    let deltaAcceptedMatches     = 0;
    let deltaAcceptedTrainings   = 0;
    let deltaRejectedMatches     = 0;
    let deltaRejectedTrainings   = 0;

    // Rulla tillbaka gammal status
    if (oldStatus === 'accepted') {
      if (isMatch)    deltaAcceptedMatches   -= 1;
      if (isTraining) deltaAcceptedTrainings -= 1;
    } else if (oldStatus === 'declined') {
      if (isMatch)    deltaRejectedMatches   -= 1;
      if (isTraining) deltaRejectedTrainings -= 1;
    }

    // Applicera ny status
    if (newStatus === 'accepted') {
      if (isMatch)    deltaAcceptedMatches   += 1;
      if (isTraining) deltaAcceptedTrainings += 1;
    } else if (newStatus === 'declined') {
      if (isMatch)    deltaRejectedMatches   += 1;
      if (isTraining) deltaRejectedTrainings += 1;
    }

    // 4) Skriv till playerStats‐dokumentet (antaget docId = `${userId}_${season}`)
    const statsRef = db.collection('playerStats')
                       .doc(`${userId}_${season}`);
    const incr     = admin.firestore.FieldValue.increment;

    await statsRef.set({
      // matcher
      ...(isMatch && {
        acceptedCallupsForMatches:   incr(deltaAcceptedMatches),
        rejectedCallupsForMatches:   incr(deltaRejectedMatches),
      }),
      // träningar
      ...(isTraining && {
        acceptedCallupsForTrainings: incr(deltaAcceptedTrainings),
        rejectedCallupsForTrainings: incr(deltaRejectedTrainings),
      }),
    }, { merge: true });
  }
);