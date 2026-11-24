# RUBBERWAY - Gestion des enquêtes RDUE

Application Flutter de collecte hors ligne des enquêtes RDUE.

## Connexion Supabase

Au lancement, les agents terrain se connectent avec l'identifiant `NomAgent_rubberway` et le mot de passe provisoire `123456`, créés depuis les Paramètres de l'application web. Après la première connexion, le nom du compte est repris dans le profil local de l'agent et la session est conservée sur le téléphone pour permettre le travail hors ligne. Supabase impose au moins 6 caractères pour les mots de passe; `1234` est donc refusé. La déconnexion est disponible sur le tableau de bord.

L'URL et la clé publique `anon` du projet Supabase sont configurées par défaut. Pour remplacer cette clé dans un environnement particulier, passez `--dart-define=SUPABASE_ANON_KEY=...` à la commande Flutter.

```powershell
flutter run
```

```powershell
flutter build apk --release
```

La clé publique peut être intégrée à l'application cliente avec des politiques RLS adaptées. Ne mettez jamais la clé `service_role` dans l'APK, dans le code Flutter ou dans Git.
