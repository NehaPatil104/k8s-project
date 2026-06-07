const request = require('supertest');
const { app } = require('../src/index');

describe('Reviews Service', () => {

  // ── Health endpoints ────────────────────────────────────────────────────────
  describe('Health Checks', () => {
    test('GET /health/live returns 200', async () => {
      const res = await request(app).get('/health/live');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('alive');
    });

    test('GET /health/ready returns 200', async () => {
      const res = await request(app).get('/health/ready');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ready');
    });
  });

  // ── GET reviews ─────────────────────────────────────────────────────────────
  describe('GET /reviews/:productId', () => {
    test('returns reviews for an existing product', async () => {
      const res = await request(app).get('/reviews/OLJCESPC7Z');
      expect(res.status).toBe(200);
      expect(res.body.productId).toBe('OLJCESPC7Z');
      expect(res.body.totalReviews).toBeGreaterThan(0);
      expect(res.body.averageRating).not.toBeNull();
      expect(Array.isArray(res.body.reviews)).toBe(true);
    });

    test('returns empty reviews for unknown product', async () => {
      const res = await request(app).get('/reviews/UNKNOWN123');
      expect(res.status).toBe(200);
      expect(res.body.totalReviews).toBe(0);
      expect(res.body.averageRating).toBeNull();
      expect(res.body.reviews).toHaveLength(0);
    });
  });

  // ── POST review ─────────────────────────────────────────────────────────────
  describe('POST /reviews', () => {
    test('creates a new review successfully', async () => {
      const res = await request(app)
        .post('/reviews')
        .send({
          productId: 'OLJCESPC7Z',
          author: 'TestUser',
          rating: 5,
          comment: 'Excellent product!',
        });
      expect(res.status).toBe(201);
      expect(res.body.author).toBe('TestUser');
      expect(res.body.rating).toBe(5);
      expect(res.body.id).toBeDefined();
    });

    test('returns 400 when required fields are missing', async () => {
      const res = await request(app)
        .post('/reviews')
        .send({ productId: 'OLJCESPC7Z' });
      expect(res.status).toBe(400);
      expect(res.body.error).toBeDefined();
    });

    test('returns 400 when rating is out of range', async () => {
      const res = await request(app)
        .post('/reviews')
        .send({
          productId: 'OLJCESPC7Z',
          author: 'TestUser',
          rating: 6,
          comment: 'Too high rating',
        });
      expect(res.status).toBe(400);
    });
  });

  // ── DELETE review ────────────────────────────────────────────────────────────
  describe('DELETE /reviews/:productId/:reviewId', () => {
    test('deletes an existing review', async () => {
      // First create one
      const created = await request(app)
        .post('/reviews')
        .send({ productId: 'TEST001', author: 'ToDelete', rating: 3, comment: 'Will be deleted' });

      const res = await request(app)
        .delete(`/reviews/TEST001/${created.body.id}`);
      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Review deleted successfully');
    });

    test('returns 404 for non-existent review', async () => {
      const res = await request(app).delete('/reviews/UNKNOWN/999');
      expect(res.status).toBe(404);
    });
  });

  // ── GET all reviews ──────────────────────────────────────────────────────────
  describe('GET /reviews', () => {
    test('returns all reviews', async () => {
      const res = await request(app).get('/reviews');
      expect(res.status).toBe(200);
      expect(res.body.totalReviews).toBeGreaterThan(0);
      expect(Array.isArray(res.body.reviews)).toBe(true);
    });
  });
});
