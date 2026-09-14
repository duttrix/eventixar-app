const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

exports.updateSellerPassword = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Tenés que entrar como admin.');
    }

    const adminSnap = await getFirestore()
      .collection('admins')
      .doc(request.auth.uid)
      .get();
    if (!adminSnap.exists) {
      throw new HttpsError('permission-denied', 'Esta cuenta no es admin.');
    }

    const sellerId =
      typeof request.data?.sellerId === 'string' ? request.data.sellerId.trim() : '';
    const password =
      typeof request.data?.password === 'string' ? request.data.password : '';
    if (!sellerId) {
      throw new HttpsError('invalid-argument', 'Falta el vendedor.');
    }
    if (password.length < 6) {
      throw new HttpsError(
        'invalid-argument',
        'La contraseña tiene que tener al menos 6 caracteres.',
      );
    }

    const sellerSnap = await getFirestore()
      .collection('sellers')
      .doc(sellerId)
      .get();
    if (!sellerSnap.exists) {
      throw new HttpsError('not-found', 'Ese vendedor no existe.');
    }

    try {
      await getAuth().updateUser(sellerId, { password });
    } catch (error) {
      const code = error && typeof error === 'object' && 'code' in error
        ? String(error.code)
        : '';
      if (code === 'auth/user-not-found') {
        throw new HttpsError('not-found', 'Ese vendedor no existe.');
      }
      throw new HttpsError('internal', 'No se pudo cambiar la contraseña.');
    }

    return { ok: true };
  },
);
