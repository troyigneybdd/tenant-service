const request = require('supertest');
const { app, setTenants } = require('../../src/tenants-api');

describe('tenant-service', () => {
  beforeEach(() => {
    setTenants([]);
  });

  test('GET /tenants returns current tenants', async () => {
    setTenants([{ namespace: 'tenant-internal', token: 'tenant-internal' }]);
    const res = await request(app).get('/tenants');
    expect(res.status).toBe(200);
    expect(res.body.tenants).toHaveLength(1);
    expect(res.body.tenants[0].namespace).toBe('tenant-internal');
  });

  test('POST /tenants requires namespace and token', async () => {
    const res = await request(app).post('/tenants').send({ namespace: 'tenant-internal' });
    expect(res.status).toBe(400);
  });

  test('POST /tenants requires token', async () => {
    const res = await request(app).post('/tenants').send({ namespace: 'tenant-internal' });
    expect(res.status).toBe(400);
  });

  test('POST /tenants rejects duplicates', async () => {
    setTenants([{ namespace: 'tenant-internal', token: 'tenant-internal' }]);
    const res = await request(app)
      .post('/tenants')
      .send({ namespace: 'tenant-internal', token: 'tenant-internal' });
    expect(res.status).toBe(409);
  });

  test('POST /tenants creates new tenant', async () => {
    const res = await request(app)
      .post('/tenants')
      .send({ namespace: 'tenant-internal', token: 'tenant-internal' });
    expect(res.status).toBe(201);
    expect(res.body.tenant.namespace).toBe('tenant-internal');
  });

  test('PUT /tenants/:namespace updates token', async () => {
    setTenants([{ namespace: 'tenant-internal', token: 'tenant-internal' }]);
    const res = await request(app)
      .put('/tenants/tenant-internal')
      .send({ token: 'new-token' });
    expect(res.status).toBe(200);
    expect(res.body.tenant.token).toBe('new-token');
  });

  test('PUT /tenants/:namespace returns 404 for missing tenant', async () => {
    const res = await request(app)
      .put('/tenants/tenant-internal')
      .send({ token: 'new-token' });
    expect(res.status).toBe(404);
  });

  test('PUT /tenants/:namespace requires token', async () => {
    setTenants([{ namespace: 'tenant-internal', token: 'tenant-internal' }]);
    const res = await request(app).put('/tenants/tenant-internal').send({});
    expect(res.status).toBe(400);
  });

  test('DELETE /tenants/:namespace removes tenant', async () => {
    setTenants([{ namespace: 'tenant-internal', token: 'tenant-internal' }]);
    const res = await request(app).delete('/tenants/tenant-internal');
    expect(res.status).toBe(200);
    const list = await request(app).get('/tenants');
    expect(list.body.tenants).toHaveLength(0);
  });

  test('DELETE /tenants/:namespace returns 404 for missing tenant', async () => {
    const res = await request(app).delete('/tenants/tenant-internal');
    expect(res.status).toBe(404);
  });
});

