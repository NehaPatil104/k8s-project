const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const client = require('prom-client');

const app = express();
const PORT = process.env.PORT || 8090;
const SERVICE_VERSION = process.env.SERVICE_VERSION || '1.0.0';

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use(express.json());
app.use(cors());
app.use(helmet());

// ─── Prometheus Metrics ───────────────────────────────────────────────────────
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestCounter = new client.Counter({
  name: 'reviews_http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

const httpRequestDuration = new client.Histogram({
  name: 'reviews_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route'],
  registers: [register],
});

// Middleware to track metrics
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer({ method: req.method, route: req.path });
  res.on('finish', () => {
    httpRequestCounter.inc({ method: req.method, route: req.path, status: res.statusCode });
    end();
  });
  next();
});

// ─── In-memory data store (in production this would be a database) ────────────
const reviews = {
  'OLJCESPC7Z': [
    { id: '1', productId: 'OLJCESPC7Z', author: 'Alice', rating: 5, comment: 'Amazing telescope! Crystal clear views.', date: '2024-01-15' },
    { id: '2', productId: 'OLJCESPC7Z', author: 'Bob', rating: 4, comment: 'Great quality, a bit pricey but worth it.', date: '2024-02-20' },
  ],
  '66VCHSJNUP': [
    { id: '3', productId: '66VCHSJNUP', author: 'Charlie', rating: 5, comment: 'Best camera bag I have ever owned!', date: '2024-03-10' },
  ],
  '1YMWWN1N4O': [
    { id: '4', productId: '1YMWWN1N4O', author: 'Diana', rating: 3, comment: 'Decent road map but could use more detail.', date: '2024-01-05' },
  ],
};

let nextId = 5;

// ─── Routes ───────────────────────────────────────────────────────────────────

// Health endpoints — used by K8s liveness + readiness probes
app.get('/health/live', (req, res) => {
  res.status(200).json({ status: 'alive', version: SERVICE_VERSION });
});

app.get('/health/ready', (req, res) => {
  res.status(200).json({ status: 'ready', version: SERVICE_VERSION });
});

// Prometheus metrics endpoint — scraped by Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// GET /reviews/:productId — get all reviews for a product
app.get('/reviews/:productId', (req, res) => {
  const { productId } = req.params;
  const productReviews = reviews[productId] || [];

  const averageRating = productReviews.length > 0
    ? (productReviews.reduce((sum, r) => sum + r.rating, 0) / productReviews.length).toFixed(1)
    : null;

  res.status(200).json({
    productId,
    totalReviews: productReviews.length,
    averageRating: averageRating ? parseFloat(averageRating) : null,
    reviews: productReviews,
  });
});

// POST /reviews — add a new review
app.post('/reviews', (req, res) => {
  const { productId, author, rating, comment } = req.body;

  // Validation
  if (!productId || !author || !rating || !comment) {
    return res.status(400).json({ error: 'productId, author, rating, and comment are required' });
  }
  if (rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'rating must be between 1 and 5' });
  }

  const newReview = {
    id: String(nextId++),
    productId,
    author,
    rating: parseInt(rating),
    comment,
    date: new Date().toISOString().split('T')[0],
  };

  if (!reviews[productId]) {
    reviews[productId] = [];
  }
  reviews[productId].push(newReview);

  res.status(201).json(newReview);
});

// DELETE /reviews/:id — delete a review
app.delete('/reviews/:productId/:reviewId', (req, res) => {
  const { productId, reviewId } = req.params;

  if (!reviews[productId]) {
    return res.status(404).json({ error: 'Product not found' });
  }

  const index = reviews[productId].findIndex(r => r.id === reviewId);
  if (index === -1) {
    return res.status(404).json({ error: 'Review not found' });
  }

  reviews[productId].splice(index, 1);
  res.status(200).json({ message: 'Review deleted successfully' });
});

// GET /reviews — get all reviews (admin endpoint)
app.get('/reviews', (req, res) => {
  const allReviews = Object.values(reviews).flat();
  res.status(200).json({
    totalReviews: allReviews.length,
    reviews: allReviews,
  });
});

// ─── Start server ─────────────────────────────────────────────────────────────
const server = app.listen(PORT, () => {
  console.log(`reviews-service v${SERVICE_VERSION} running on port ${PORT}`);
});

// Graceful shutdown — K8s sends SIGTERM before killing the pod
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

module.exports = { app, reviews };
