/**
 * 🔧 MIGRAÇÃO SIMPLES — Sem SDK, sem service account
 *
 * COMO USAR:
 *  1. Abra o Firebase Console → Realtime Database → ⋮ → Exportar JSON
 *  2. Salve o arquivo como "firebase_export.json" na mesma pasta deste script
 *  3. node migrate_missions_recurrence.js
 *  4. Será gerado "firebase_migrated.json"
 *  5. No Firebase Console → Realtime Database → ⋮ → Importar JSON
 *     → selecione "firebase_migrated.json"
 *
 *  ⚠️  O import SUBSTITUI todos os dados — guarde o original como backup.
 */

const fs = require('fs');

const INPUT_FILE  = './firebase_export.json';
const OUTPUT_FILE = './firebase_migrated.json';

console.log('\n╔══════════════════════════════════════════════════════════╗');
console.log('║   MIGRAÇÃO: Sistema de Recorrência de Missões            ║');
console.log('╚══════════════════════════════════════════════════════════╝\n');

if (!fs.existsSync(INPUT_FILE)) {
  console.error('❌  Arquivo "firebase_export.json" não encontrado.');
  console.error('    Exporte pelo Firebase Console e salve com esse nome.');
  process.exit(1);
}

const data = JSON.parse(fs.readFileSync(INPUT_FILE, 'utf8'));

let missionsUpdated = 0;
let usersUpdated    = 0;

for (const [serverId, serverObj] of Object.entries(data.serverData || {})) {

  // ── Missões fixas: adiciona recurrence: null ──────────────────────────────
  for (const [userId, userDays] of Object.entries(serverObj?.dailyMissions || {})) {
    for (const [dateKey, dayData] of Object.entries(userDays)) {
      for (const [missionId, mission] of Object.entries(dayData?.fixed || {})) {
        if (mission.recurrence === undefined) {
          mission.recurrence = null;
          missionsUpdated++;
          console.log(`  ✅ [${serverId}] ${userId}/${dateKey}/${missionId}`);
        }
      }
    }
  }

  // ── Usuários: marca schemaVersion 2 ──────────────────────────────────────
  for (const [userId, user] of Object.entries(serverObj?.users || {})) {
    if (!user.schemaVersion || user.schemaVersion < 2) {
      user.schemaVersion = 2;
      usersUpdated++;
      console.log(`  👤 [${serverId}] ${user.name || userId}`);
    }
  }
}

// Registra a migração
(data.migrations = data.migrations || {}).v2_recurrence = {
  version: 2,
  migratedAt: Date.now(),
  description: 'Campo recurrence adicionado nas missões fixas',
};

fs.writeFileSync(OUTPUT_FILE, JSON.stringify(data, null, 2), 'utf8');

console.log('\n╔══════════════════════════════════════════════════════════╗');
console.log(`║  Missões atualizadas: ${String(missionsUpdated).padEnd(34)}║`);
console.log(`║  Usuários atualizados: ${String(usersUpdated).padEnd(33)}║`);
console.log(`║  Arquivo gerado: firebase_migrated.json                  ║`);
console.log('╠══════════════════════════════════════════════════════════╣');
console.log('║  Agora: Firebase Console → Database → ⋮ → Importar JSON ║');
console.log('╚══════════════════════════════════════════════════════════╝\n');