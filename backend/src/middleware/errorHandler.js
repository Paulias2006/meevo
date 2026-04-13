export function notFoundHandler(_request, response) {
  return response.status(404).json({
    message: 'Route introuvable.',
  });
}

export function errorHandler(error, _request, response, _next) {
  if (error?.type === 'entity.too.large' || error?.status === 413) {
    return response.status(413).json({
      message:
        'Le fichier est trop lourd pour etre televerse. Compressez la video ou choisissez un fichier plus leger.',
    });
  }

  if (error?.name === 'ZodError') {
    return response.status(400).json({
      message: 'Donnees invalides.',
      details: error.issues,
    });
  }

  if (error?.name === 'ValidationError') {
    return response.status(400).json({
      message: 'Validation echouee.',
      details: Object.values(error.errors).map((issue) => issue.message),
    });
  }

  if (error?.code === 11000) {
    return response.status(409).json({
      message: 'Une ressource avec ces informations existe deja.',
    });
  }

  return response.status(error.statusCode ?? 500).json({
    message: error.message ?? 'Erreur interne du serveur.',
  });
}
