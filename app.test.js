// app.test.js
// Minimal test for app.js - used in Jenkinsfile
const request = require('supertest');
const app = require('./app');

test('GET / returns Hello World!', async () => {
  const res = await request(app).get('/');
  expect(res.status).toBe(200);
  expect(res.text).toBe('Hello World!');
});
