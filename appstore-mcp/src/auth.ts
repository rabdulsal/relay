/**
 * App Store Connect API auth — ES256 JWT minted with node:crypto (no deps).
 * https://developer.apple.com/documentation/appstoreconnectapi/generating_tokens_for_api_requests
 */

import { createPrivateKey, sign, type KeyObject } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";

export interface AscCredentials {
  keyId: string;
  issuerId: string;
  privateKey: KeyObject;
}

export function credentialProblems(): string[] {
  const problems: string[] = [];
  if (!process.env.APPLE_KEY_ID) problems.push("APPLE_KEY_ID is not set (ASC API key ID)");
  if (!process.env.APPLE_ISSUER_ID) problems.push("APPLE_ISSUER_ID is not set (ASC issuer ID)");
  if (!process.env.APPLE_KEY_CONTENT && !process.env.ASC_KEY_PATH) {
    problems.push("Neither APPLE_KEY_CONTENT (base64 .p8) nor ASC_KEY_PATH (path to .p8) is set");
  } else if (process.env.ASC_KEY_PATH && !existsSync(process.env.ASC_KEY_PATH)) {
    problems.push(`ASC_KEY_PATH points to a missing file: ${process.env.ASC_KEY_PATH}`);
  }
  return problems;
}

function loadCredentials(): AscCredentials {
  const problems = credentialProblems();
  if (problems.length) {
    throw new Error(
      `App Store Connect credentials missing:\n  - ${problems.join("\n  - ")}\n` +
      `Generate a key at App Store Connect → Users and Access → Integrations → App Store Connect API.`,
    );
  }
  const pem = process.env.ASC_KEY_PATH
    ? readFileSync(process.env.ASC_KEY_PATH, "utf8")
    : Buffer.from(process.env.APPLE_KEY_CONTENT!, "base64").toString("utf8");
  return {
    keyId: process.env.APPLE_KEY_ID!,
    issuerId: process.env.APPLE_ISSUER_ID!,
    privateKey: createPrivateKey(pem),
  };
}

function b64url(buf: Buffer): string {
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let cached: { token: string; exp: number } | null = null;

/** Mint (or reuse) a short-lived ASC API bearer token. */
export function mintToken(): string {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - now > 120) return cached.token;

  const creds = loadCredentials();
  const header = { alg: "ES256", kid: creds.keyId, typ: "JWT" };
  const exp = now + 1200; // Apple max is 20 minutes
  const payload = { iss: creds.issuerId, iat: now, exp, aud: "appstoreconnect-v1" };
  const signingInput =
    `${b64url(Buffer.from(JSON.stringify(header)))}.${b64url(Buffer.from(JSON.stringify(payload)))}`;
  // JWT ES256 requires the raw (r,s) concatenated signature, not ASN.1/DER
  const signature = sign("sha256", Buffer.from(signingInput), {
    key: creds.privateKey,
    dsaEncoding: "ieee-p1363",
  });
  const token = `${signingInput}.${b64url(signature)}`;
  cached = { token, exp };
  return token;
}
