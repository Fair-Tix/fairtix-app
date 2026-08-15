import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
admin.initializeApp();

export const helloFairtix = functions.https.onCall((request) => {
  return {message: "FairTix backend is alive"};
});