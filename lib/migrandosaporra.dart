// migrate.dart
//
// Executa a migração completa para o Firebase Realtime Database.
// Como você já está conectado via FlutterFire CLI, não precisa configurar nada.
//
// Rode com: dart migrate.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('🚀 Iniciando migração...');

  await FirebaseDatabase.instance.ref('/').set(_data);

  print('✅ Migração concluída!');
}

final _data = {
  'servers': {
    'server_2026_01': {
      'maxPlayers': 1000,
      'name': 'Servidor Janeiro 2026',
      'openDate': '2026-01-01T00:00:00Z',
      'playerCount': 0,
      'status': 'active',
    },
    'server_2026_02': {
      'maxPlayers': 1000,
      'name': 'Servidor Fevereiro 2026',
      'openDate': '2026-02-01T00:00:00.000',
      'playerCount': 2,
      'status': 'active',
    },
  },
  'userServers': {
    'Hnj4dM0v96gNL18zEoGyFbbDEdm1': 'server_2026_02',
    'vO1BP4TZCGPqrhH6r9Kxu1nmiht1': 'server_2026_02',
  },
  'serverData': {
    'server_2026_02': {
      'users': {
        'Hnj4dM0v96gNL18zEoGyFbbDEdm1': {
          'createdAt': '2026-02-06T12:52:34.946352',
          'email': 'viitiinmec@gmail.com',
          'lastSeen': '2026-02-26T16:58:13.288969',
          'level': 21,
          'name': 'MONARCA',
          'rank': 'SS',
          'terms': true,
          'totalXp': 34230,
          'xp': 33500,
          'stats': {
            'attributes': {
              'discipline': 100,
              'evolution': 100,
              'habit': 100,
              'shape': 100,
              'study': 100,
            },
            'bestStreak': 0,
            'currentStreak': 0,
            'totalMissionsCompleted': 80,
          },
        },
        'vO1BP4TZCGPqrhH6r9Kxu1nmiht1': {
          'createdAt': '2026-02-06T18:03:34.456687',
          'email': 'samuk3206@gmail.com',
          'lastSeen': '2026-02-22T19:14:32.418661',
          'level': 2,
          'name': 'samuka0',
          'rank': 'E',
          'terms': true,
          'totalXp': 605,
          'xp': 0,
          'stats': {
            'attributes': {
              'discipline': 0,
              'evolution': 1,
              'habit': 0,
              'shape': 1,
              'study': 4,
            },
            'bestStreak': 0,
            'currentStreak': 0,
            'totalMissionsCompleted': 6,
          },
        },
      },
      'dailyMissions': {
        'Hnj4dM0v96gNL18zEoGyFbbDEdm1': {
          '2026-02-06': {
            'custom': {
              'custom_1770394126605': {'completed': true,  'completedAt': 1770394986306, 'name': 'atualizar snackbar de login acreen dados errados', 'xp': 35},
              'custom_1770394148718': {'completed': true,  'completedAt': 1770396943581, 'name': 'colocar particles em todas as telas do app', 'xp': 35},
              'custom_1770394496341': {'completed': true,  'completedAt': 1770397742326, 'name': 'corrigir cálculo de quanto o server tá sendo cheio', 'xp': 35},
            },
            'fixed': {
              'fixed_1770394015497': {'completed': true,  'completedAt': 1770429034885, 'name': 'Treino', 'xp': 60},
              'fixed_1770394022246': {'completed': true,  'completedAt': 1770429037968, 'name': 'Finalizar app', 'xp': 60},
              'fixed_1770394039192': {'completed': true,  'completedAt': 1770411578124, 'name': 'Ler a bíblia', 'xp': 60},
              'fixed_1770394046024': {'completed': true,  'completedAt': 1770429032571, 'name': 'Ir ao culto', 'xp': 60},
              'fixed_1770394090247': {'completed': true,  'completedAt': 1770429033342, 'name': 'Ajustar site', 'xp': 60},
            },
          },
          '2026-02-07': {
            'custom': {
              'custom_1770484078616': {'completed': true, 'completedAt': 1770484079884, 'name': 'rs', 'xp': 240},
            },
          },
          '2026-02-08': {
            'custom': {
              'custom_1770588837746': {'completed': true, 'completedAt': 1770588839580, 'name': 'Finalizar o app', 'xp': 105},
            },
            'fixed': {
              'fixed_1770588830200': {'completed': true, 'completedAt': 1770588854628, 'name': 'Programar', 'xp': 200},
            },
          },
          '2026-02-09': {
            'fixed': {
              'fixed_1770674905485': {'completed': true,  'completedAt': 1770674949194, 'name': 'Estudar Enem bloco 1', 'xp': 60},
              'fixed_1770674913734': {'completed': false, 'name': 'Estudar Enem bloco 2', 'xp': 60},
              'fixed_1770674920083': {'completed': true,  'completedAt': 1770674951992, 'name': 'Programar', 'xp': 60},
              'fixed_1770674926447': {'completed': true,  'completedAt': 1770674944407, 'name': 'Estudar inglês', 'xp': 60},
              'fixed_1770674938012': {'completed': false, 'name': 'Ir dormir no horário correto', 'xp': 60},
            },
          },
          '2026-02-11': {
            'fixed': {
              'fixed_1770862367753': {'completed': true, 'completedAt': 1770862372933, 'name': 'estudar inglês', 'xp': 60},
            },
          },
          '2026-02-17': {
            'fixed': {
              'fixed_1771359552912': {'completed': true, 'completedAt': 1771360126199, 'name': 'estudar inglês', 'xp': 60},
            },
          },
          '2026-02-18': {
            'custom': {
              'custom_1771420155781': {'completed': true, 'completedAt': 1771420157268, 'name': 'estudar aritmética basica', 'xp': 110},
            },
            'fixed': {
              'fixed_1771420197354': {'completed': true, 'completedAt': 1771420198622, 'name': 'Estudar matemática', 'xp': 220},
              'fixed_1771420284925': {'completed': true, 'completedAt': 1771420286042, 'name': 'Estudar inglês', 'xp': 230},
            },
          },
        },
        'vO1BP4TZCGPqrhH6r9Kxu1nmiht1': {
          '2026-02-20': {
            'custom': {
              'custom_1771619176558': {'completed': true, 'completedAt': 1771619178364, 'name': 'terminar o mão de obra', 'xp': 35},
              'custom_1771619202122': {'completed': true, 'completedAt': 1771619204327, 'name': 'terminar o nivex', 'xp': 35},
              'custom_1771619245652': {'completed': true, 'completedAt': 1771619247273, 'name': 'terminar o tabu', 'xp': 35},
            },
            'fixed': {
              'fixed_1771619154384': {'completed': true,  'completedAt': 1771619294426, 'name': 'Atualizar projetos', 'xp': 60},
              'fixed_1771619267208': {'completed': false, 'name': 'treinar', 'xp': 60},
              'fixed_1771619288614': {'completed': false, 'name': 'cumprir todos os 7 hábitos', 'xp': 60},
            },
          },
          '2026-02-21': {
            'custom': {
              'custom_1771676010007': {'completed': true, 'completedAt': 1771702485739, 'name': 'Terminar o tabu', 'xp': 35},
              'custom_1771676588860': {'completed': true, 'completedAt': 1771676592818, 'name': 'arrumar as cores', 'xp': 35},
              'custom_1771702518346': {'completed': true, 'completedAt': 1771702520437, 'name': 'terminar a primeira versão da Arcanjo', 'xp': 40},
            },
            'fixed': {
              'fixed_1771675986496': {'completed': true,  'completedAt': 1771676019598, 'name': 'Atualizar o site atual', 'xp': 60},
              'fixed_1771675994394': {'completed': true,  'completedAt': 1771702481430, 'name': 'Treinar', 'xp': 60},
              'fixed_1771702536081': {'completed': true,  'completedAt': 1771724655236, 'name': 'Arrumar outro projeto', 'xp': 70},
              'fixed_1771724669574': {'completed': true,  'completedAt': 1771724672031, 'name': 'atualizar o projeto atual', 'xp': 70},
              'fixed_1771724696257': {'completed': false, 'name': 'atualizar o projeto atual', 'xp': 70},
            },
          },
          '2026-02-22': {
            'fixed': {
              'fixed_1771798468893': {'completed': true, 'completedAt': 1771798471298, 'name': 'achar um projeto', 'xp': 70},
            },
          },
        },
      },
      'transactions': {
        'Hnj4dM0v96gNL18zEoGyFbbDEdm1': {
          'discipline_5fixed_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2026-02-06':        {'actionData': {'date': '2026-02-06', 'fixedCount': 5},        'actionType': 'discipline_bonus_5fixed', 'executed': true, 'result': {'discipline': 2},  'timestamp': 1770429038813},
          'discipline_all_fixed_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2026-02-11':     {'actionData': {'bonus': 2, 'date': '2026-02-11'},              'actionType': 'discipline_all_fixed',    'executed': true, 'result': {'discipline': 2},  'timestamp': 1770862373977},
          'discipline_all_fixed_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2026-02-17':     {'actionData': {'bonus': 2, 'date': '2026-02-17'},              'actionType': 'discipline_all_fixed',    'executed': true, 'result': {'discipline': 80}, 'timestamp': 1771360127340},
          'discipline_all_fixed_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2026-02-18':     {'actionData': {'bonus': 2, 'date': '2026-02-18'},              'actionType': 'discipline_all_fixed',    'executed': true, 'result': {'discipline': 80}, 'timestamp': 1771420199701},
          'habit_all_custom_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2026-02-18':         {'actionData': {'bonus': 2, 'date': '2026-02-18'},              'actionType': 'habit_all_custom',        'executed': true, 'result': {'habit': 99},      'timestamp': 1771420158367},
          'habit_all_fixed_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2026-02-11':          {'actionData': {'bonus': 1, 'date': '2026-02-11'},              'actionType': 'habit_all_fixed',         'executed': true, 'result': {'habit': 1},       'timestamp': 1770862374719},
          'habit_all_fixed_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2026-02-17':          {'actionData': {'bonus': 1, 'date': '2026-02-17'},              'actionType': 'habit_all_fixed',         'executed': true, 'result': {'habit': 97},      'timestamp': 1771360127901},
          'habit_all_fixed_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2026-02-18':          {'actionData': {'bonus': 1, 'date': '2026-02-18'},              'actionType': 'habit_all_fixed',         'executed': true, 'result': {'habit': 98},      'timestamp': 1771420200224},
          'levelup_evolution_Hnj4dM0v96gNL18zEoGyFbbDEdm1_2':                  {'actionData': {'newLevel': 2,  'oldLevel': 1},                 'actionType': 'evolution_levelup',       'executed': true, 'result': {'evolution': 1},   'timestamp': 1770429034062},
          'levelup_evolution_Hnj4dM0v96gNL18zEoGyFbbDEdm1_17':                 {'actionData': {'newLevel': 17, 'oldLevel': 16},                'actionType': 'evolution_levelup',       'executed': true, 'result': {'evolution': 85},  'timestamp': 1771420158945},
          'levelup_evolution_Hnj4dM0v96gNL18zEoGyFbbDEdm1_18':                 {'actionData': {'newLevel': 18, 'oldLevel': 17},                'actionType': 'evolution_levelup',       'executed': true, 'result': {'evolution': 86},  'timestamp': 1771420200748},
          'levelup_evolution_Hnj4dM0v96gNL18zEoGyFbbDEdm1_21':                 {'actionData': {'newLevel': 21, 'oldLevel': 20},                'actionType': 'evolution_levelup',       'executed': true, 'result': {'evolution': 91},  'timestamp': 1771420287160},
          'rankup_evolution_Hnj4dM0v96gNL18zEoGyFbbDEdm1_S':                   {'actionData': {'newRank': 'S',  'oldRank': 'A'},               'actionType': 'evolution_rankup',        'executed': true, 'result': {'evolution': 5},   'timestamp': 1770484080652},
          'rankup_evolution_Hnj4dM0v96gNL18zEoGyFbbDEdm1_SS':                  {'actionData': {'newRank': 'SS', 'oldRank': 'S'},               'actionType': 'evolution_rankup',        'executed': true, 'result': {'evolution': 90},  'timestamp': 1771420201284},
          'shape_Hnj4dM0v96gNL18zEoGyFbbDEdm1_fixed_1770394015497_2026-02-06': {'actionData': {'date': '2026-02-06', 'missionId': 'fixed_1770394015497',   'missionName': 'Treino'},                    'actionType': 'shape_mission', 'executed': true, 'result': {'shape': 1},  'timestamp': 1770429035455},
          'study_Hnj4dM0v96gNL18zEoGyFbbDEdm1_fixed_1770394039192_2026-02-06': {'actionData': {'date': '2026-02-06', 'missionId': 'fixed_1770394039192',   'missionName': 'Ler a bíblia'},              'actionType': 'study_mission', 'executed': true, 'result': {'study': 1},  'timestamp': 1770411578615},
          'study_Hnj4dM0v96gNL18zEoGyFbbDEdm1_fixed_1770674905485_2026-02-09': {'actionData': {'date': '2026-02-09', 'missionId': 'fixed_1770674905485',   'missionName': 'Estudar Enem bloco 1'},      'actionType': 'study_mission', 'executed': true, 'result': {'study': 2},  'timestamp': 1770674949750},
          'study_Hnj4dM0v96gNL18zEoGyFbbDEdm1_fixed_1770674926447_2026-02-09': {'actionData': {'date': '2026-02-09', 'missionId': 'fixed_1770674926447',   'missionName': 'Estudar inglês'},            'actionType': 'study_mission', 'executed': true, 'result': {'study': 1},  'timestamp': 1770674944929},
          'study_Hnj4dM0v96gNL18zEoGyFbbDEdm1_fixed_1770862367753_2026-02-11': {'actionData': {'date': '2026-02-11', 'missionId': 'fixed_1770862367753',   'missionName': 'estudar inglês'},            'actionType': 'study_mission', 'executed': true, 'result': {'study': 3},  'timestamp': 1770862373455},
          'study_Hnj4dM0v96gNL18zEoGyFbbDEdm1_fixed_1771359552912_2026-02-17': {'actionData': {'date': '2026-02-17', 'missionId': 'fixed_1771359552912',   'missionName': 'estudar inglês'},            'actionType': 'study_mission', 'executed': true, 'result': {'study': 68}, 'timestamp': 1771360126752},
          'study_Hnj4dM0v96gNL18zEoGyFbbDEdm1_fixed_1771420197354_2026-02-18': {'actionData': {'date': '2026-02-18', 'missionId': 'fixed_1771420197354',   'missionName': 'Estudar matemática'},        'actionType': 'study_mission', 'executed': true, 'result': {'study': 68}, 'timestamp': 1771420199159},
          'study_Hnj4dM0v96gNL18zEoGyFbbDEdm1_fixed_1771420284925_2026-02-18': {'actionData': {'date': '2026-02-18', 'missionId': 'fixed_1771420284925',   'missionName': 'Estudar inglês'},            'actionType': 'study_mission', 'executed': true, 'result': {'study': 68}, 'timestamp': 1771420286586},
          'study_Hnj4dM0v96gNL18zEoGyFbbDEdm1_custom_1771420155781_2026-02-18':{'actionData': {'date': '2026-02-18', 'missionId': 'custom_1771420155781',  'missionName': 'estudar aritmética basica'}, 'actionType': 'study_mission', 'executed': true, 'result': {'study': 68}, 'timestamp': 1771420157801},
        },
        'vO1BP4TZCGPqrhH6r9Kxu1nmiht1': {
          'levelup_evolution_vO1BP4TZCGPqrhH6r9Kxu1nmiht1_2':                  {'actionData': {'newLevel': 2, 'oldLevel': 1},                                                                          'actionType': 'evolution_levelup', 'executed': true, 'result': {'evolution': 1}, 'timestamp': 1771676593638},
          'shape_vO1BP4TZCGPqrhH6r9Kxu1nmiht1_fixed_1771675994394_2026-02-21': {'actionData': {'date': '2026-02-21', 'missionId': 'fixed_1771675994394', 'missionName': 'Treinar'},                    'actionType': 'shape_mission',     'executed': true, 'result': {'shape': 1},    'timestamp': 1771702482275},
          'study_vO1BP4TZCGPqrhH6r9Kxu1nmiht1_fixed_1771619154384_2026-02-20': {'actionData': {'date': '2026-02-20', 'missionId': 'fixed_1771619154384', 'missionName': 'Atualizar projetos'},         'actionType': 'study_mission',     'executed': true, 'result': {'study': 1},    'timestamp': 1771619295116},
          'study_vO1BP4TZCGPqrhH6r9Kxu1nmiht1_fixed_1771702536081_2026-02-21': {'actionData': {'date': '2026-02-21', 'missionId': 'fixed_1771702536081', 'missionName': 'Arrumar outro projeto'},      'actionType': 'study_mission',     'executed': true, 'result': {'study': 2},    'timestamp': 1771724655871},
          'study_vO1BP4TZCGPqrhH6r9Kxu1nmiht1_fixed_1771724669574_2026-02-21': {'actionData': {'date': '2026-02-21', 'missionId': 'fixed_1771724669574', 'missionName': 'atualizar o projeto atual'},  'actionType': 'study_mission',     'executed': true, 'result': {'study': 3},    'timestamp': 1771724672602},
          'study_vO1BP4TZCGPqrhH6r9Kxu1nmiht1_fixed_1771798468893_2026-02-22': {'actionData': {'date': '2026-02-22', 'missionId': 'fixed_1771798468893', 'missionName': 'achar um projeto'},           'actionType': 'study_mission',     'executed': true, 'result': {'study': 4},    'timestamp': 1771798472057},
        },
      },
    },
  },
};