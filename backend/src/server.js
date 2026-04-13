import http from 'http';
import os from 'os';
import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import { createApp } from './app.js';
import { connectDatabase } from './config/database.js';
import { env } from './config/env.js';

async function bootstrap() {
  await connectDatabase(env.MONGODB_URI);

  const httpServer = http.createServer();
  const io = new Server(httpServer, {
    cors: {
      origin: env.CLIENT_ORIGIN === '*' ? true : env.CLIENT_ORIGIN,
      credentials: true,
    },
  });

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;

    if (!token) {
      return next();
    }

    try {
      const payload = jwt.verify(token, env.JWT_SECRET);
      socket.user = payload;
      return next();
    } catch (error) {
      return next(new Error('Token invalide'));
    }
  });

  io.on('connection', (socket) => {
    if (socket.user?.sub) {
      socket.join(`user:${socket.user.sub}`);
      socket.join(`role:${socket.user.role}`);
    }

    socket.emit('system:connected', {
      connectedAt: new Date().toISOString(),
    });
  });

  const app = createApp(io);
  httpServer.removeAllListeners('request');
  httpServer.on('request', app);
  httpServer.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
      console.error(
        `Le port ${env.PORT} est deja utilise. Arretez l ancien serveur ou changez PORT dans backend/.env.`,
      );
      process.exit(1);
    }

    console.error('Erreur reseau du serveur:', error);
    process.exit(1);
  });

  const host = env.HOST || '0.0.0.0';
  httpServer.listen(env.PORT, host, () => {
    console.log(`Meevo backend running on http://localhost:${env.PORT}`);

    if (host === '0.0.0.0') {
      const interfaces = os.networkInterfaces();
      const addresses = Object.values(interfaces)
        .flat()
        .filter(
          (entry) =>
            entry &&
            entry.family === 'IPv4' &&
            entry.internal === false,
        )
        .map((entry) => `http://${entry.address}:${env.PORT}`);

      if (addresses.length > 0) {
        console.log('Accessible sur le reseau local:');
        addresses.forEach((addr) => console.log(`- ${addr}`));
      }
    } else {
      console.log(`Host explicite: http://${host}:${env.PORT}`);
    }
  });
}

bootstrap().catch((error) => {
  console.error('Impossible de demarrer le backend:', error);
  process.exit(1);
});
