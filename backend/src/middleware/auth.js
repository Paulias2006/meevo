import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { User } from '../models/User.js';

export async function requireAuth(request, response, next) {
  const header = request.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return response.status(401).json({
      message: 'Authentification requise.',
    });
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET);
    const user = await User.findById(payload.sub);

    if (!user) {
      return response.status(401).json({
        message: 'Utilisateur introuvable.',
      });
    }

    request.user = user;
    next();
  } catch (error) {
    return response.status(401).json({
      message: 'Session invalide ou expiree.',
    });
  }
}

export function requireRole(...roles) {
  return (request, response, next) => {
    if (!request.user || !roles.includes(request.user.role)) {
      return response.status(403).json({
        message: 'Permission refusee.',
      });
    }

    next();
  };
}

export function requirePartnerSubscriptionAccess(request, response, next) {
  if (!request.user) {
    return response.status(401).json({
      message: 'Authentification requise.',
    });
  }

  if (request.user.role === 'admin' || request.user.hasOperationalPartnerAccess?.()) {
    return next();
  }

  return response.status(402).json({
    message:
      'Un abonnement partenaire actif est requis pour acceder a ce dashboard.',
  });
}
