# Meevo Backend

## Demarrage local

1. Le fichier `.env` est deja present pour le developpement local.
2. Verifiez que MongoDB tourne sur `mongodb://127.0.0.1:27017/meevo`.
3. Lancez:

```bash
npm install
npm run dev
```

## Jeu de donnees de test

Pour remplir rapidement MongoDB avec 50 lieux de demonstration visibles dans l'app:

```bash
npm run seed:venues-demo
```

Le script:

- cree ou met a jour un compte partenaire demo
- ajoute 50 lieux publies repartis sur plusieurs villes du Togo
- remplit photos, video, capacite, prix, horaires, Maps et quelques blocages de planning

## Variables importantes

- `PORT`: port HTTP du backend
- `MONGODB_URI`: base MongoDB locale ou Atlas
- `JWT_SECRET`: secret JWT
- `CLIENT_ORIGIN`: origine front autorisee

## Deploiement sur Render

1. Crée ton compte Render et connecte ton dépôt GitHub.
2. Dans Render, crée un nouveau service web.
3. Utilise :
   - Root Directory : `backend`
   - Build Command : `npm install`
   - Start Command : `npm start`
4. Ajoute ces variables d'environnement dans Render :
   - `NODE_ENV=production`
   - `MONGODB_URI=<ta chaine Atlas>`
   - `JWT_SECRET=<un secret long>`
   - `CLIENT_ORIGIN=<adresse du frontend>`
   - `PUBLIC_BASE_URL=<URL publique du backend ou vide>`
5. Autorise ton IP dans MongoDB Atlas (ou temporairement `0.0.0.0/0`).
6. Déploie le service.

> Render fournit automatiquement `PORT`, donc tu n'as pas besoin de le définir manuellement là-bas.

## Media des salles

Le backend stocke des URLs dans:

- `coverPhoto`
- `photos`
- `videoUrl`

Flux recommande:

1. Un partenaire accepte de collaborer avec Meevo.
2. Vous creez son compte `partner`.
3. Vous creez la salle via `POST /api/venues`.
4. Les photos/videos sont chargees sur un stockage media externe:
   - Cloudinary
   - AWS S3
   - Supabase Storage
5. Les URLs generees sont enregistrees dans `coverPhoto`, `photos`, `videoUrl`.
6. La salle est publiee et visible en temps reel.

## Planning temps reel

- `GET /api/venues/:id/availability?date=YYYY-MM-DD`
- `POST /api/bookings`
- `PATCH /api/bookings/:id/status`

Chaque reservation utilise:

- `eventDate`
- `startTime`
- `endTime`

Le backend:

- refuse les chevauchements horaires
- tient compte des blocages manuels de salle
- emet `calendar:updated` via Socket.IO apres chaque changement

Exemple de reponse calendrier:

```json
{
  "date": "2026-04-10",
  "businessHours": {
    "opensAt": "08:00",
    "closesAt": "23:00"
  },
  "blockedDates": [],
  "slots": [
    {
      "source": "booking",
      "date": "2026-04-10",
      "startTime": "10:00",
      "endTime": "15:00",
      "status": "confirmed",
      "eventType": "Mariage"
    }
  ]
}
```
