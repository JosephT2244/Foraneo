// Local, offline encryption. Passwords and derived keys never leave this device.
const VAULT_KEY = 'foraneo-vault-v1';
const ITERATIONS = 310000;
const encoder = new TextEncoder();
const decoder = new TextDecoder();
function base64(bytes) { let value = ''; for (const byte of bytes) value += String.fromCharCode(byte); return btoa(value); }
function bytes(value) { return Uint8Array.from(atob(value), c => c.charCodeAt(0)); }
export function validateVault(vault) {
  if (!vault || vault.format !== 'foraneo-vault' || vault.version !== 1 || typeof vault.username !== 'string' || !vault.username.trim() || vault.username !== vault.username.trim() || vault.username.length > 80 || vault.iterations !== ITERATIONS || typeof vault.ciphertext !== 'string' || vault.ciphertext.length > 24000000 || !/^[A-Za-z0-9+/]+={0,2}$/.test(vault.ciphertext) || bytes(vault.ciphertext).length < 16 || typeof vault.salt !== 'string' || vault.salt.length > 24 || typeof vault.iv !== 'string' || vault.iv.length > 16 || bytes(vault.salt).length !== 16 || bytes(vault.iv).length !== 12) throw new Error('El respaldo cifrado no es válido.');
  return vault;
}
async function derive(password, salt) {
  const material = await crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey({ name: 'PBKDF2', salt, iterations: ITERATIONS, hash: 'SHA-256' }, material, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
}
export class LocalAuth {
  constructor(storage) { this.storage = storage; this.key = null; this.vault = null; this.writes = Promise.resolve(); const raw = storage.getItem(VAULT_KEY); if (raw) this.vault = validateVault(JSON.parse(raw)); }
  get hasAccount() { return Boolean(this.vault); }
  get username() { return this.vault?.username || ''; }
  get unlocked() { return Boolean(this.key); }
  async create(username, password, data) {
    username = username.trim();
    if (!username || username.length > 80 || password.length < 10) throw new Error('Usa un nombre y una contraseña de al menos 10 caracteres.');
    if (!globalThis.crypto?.subtle) throw new Error('El cifrado requiere HTTPS o localhost.');
    await this.writes.catch(() => {});
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const key = await derive(password, salt);
    const previous = this.vault, previousKey = this.key;
    this.vault = { format: 'foraneo-vault', version: 1, username, iterations: ITERATIONS, salt: base64(salt) };
    this.key = key;
    try { await this.save(data); } catch (error) { this.vault = previous; this.key = previousKey; throw error; }
  }
  async unlock(username, password, suppliedVault) {
    const vault = validateVault(suppliedVault || this.vault);
    if (username.trim() !== vault.username) throw new Error('Usuario o contraseña incorrectos.');
    const key = await derive(password, bytes(vault.salt));
    let data;
    try { data = JSON.parse(decoder.decode(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: bytes(vault.iv), additionalData: encoder.encode(vault.username) }, key, bytes(vault.ciphertext)))); }
    catch { throw new Error('Usuario o contraseña incorrectos, o respaldo dañado.'); }
    this.key = key; this.vault = vault;
    return data;
  }
  save(data) {
    if (!this.key) return Promise.reject(new Error('Primero desbloquea tu perfil.'));
    // Snapshot immediately, then serialize writes: a slower encryption must
    // never overwrite a newer edit or observe data changed during its await.
    const plaintext = encoder.encode(JSON.stringify(data)), key = this.key, metadata = { ...this.vault };
    const write = this.writes.catch(() => {}).then(async () => {
      const iv = crypto.getRandomValues(new Uint8Array(12));
      const ciphertext = await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: encoder.encode(metadata.username) }, key, plaintext);
      const vault = { ...metadata, iv: base64(iv), ciphertext: base64(new Uint8Array(ciphertext)) };
      this.storage.setItem(VAULT_KEY, JSON.stringify(vault));
      this.vault = vault;
    });
    this.writes = write;
    return write;
  }
  lock() { this.key = null; }
  export() { return JSON.stringify(this.vault, null, 2); }
}
