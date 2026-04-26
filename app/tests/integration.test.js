const request = require('supertest');
const { app } = require('../index');

describe('Integration Tests', () => {
  test('GET /health should return 200 OK and UP status', async () => {
    const response = await request(app).get('/health');
    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({ status: 'UP' });
  });

  test('GET /unknown-route should return 404', async () => {
    const response = await request(app).get('/unknown-route');
    expect(response.statusCode).toBe(404);
  });
});
