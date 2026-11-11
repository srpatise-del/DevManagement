function errorHandler(err, req, res, next) {
  console.error('Error encountered:', err.stack || err.message);

  const statusCode = err.statusCode || 500;
  const message = statusCode === 500 ? 'Internal Server Error' : err.message;

  res.status(statusCode).json({
    success: false,
    error: {
      code: statusCode,
      message: message,
    },
  });
}

module.exports = errorHandler;
