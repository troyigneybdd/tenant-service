const express = require('express');
const app = express();

const { envInt } = require('./env');

const PORT = envInt('SERVICE_PORT', 8080);

let tenants = [
  { namespace: 'tenant-internal', token: 'tenant-internal' }
];

app.use(express.json());

app.get('/tenants', (req, res) => {
  res.json({ tenants });
});

app.post('/tenants', (req, res) => {
  const { namespace, token } = req.body;
  
  if (!namespace || !token) {
    return res.status(400).json({ error: 'namespace and token required' });
  }

  const exists = tenants.find(t => t.namespace === namespace);
  if (exists) {
    return res.status(409).json({ error: 'tenant already exists' });
  }

  tenants.push({ namespace, token });
  console.log(`Added tenant: ${namespace}`);
  res.status(201).json({ message: 'tenant added', tenant: { namespace, token } });
});

app.delete('/tenants/:namespace', (req, res) => {
  const { namespace } = req.params;
  const initialLength = tenants.length;
  
  tenants = tenants.filter(t => t.namespace !== namespace);
  
  if (tenants.length === initialLength) {
    return res.status(404).json({ error: 'tenant not found' });
  }

  console.log(`Removed tenant: ${namespace}`);
  res.json({ message: 'tenant removed', namespace });
});

app.put('/tenants/:namespace', (req, res) => {
  const { namespace } = req.params;
  const { token } = req.body;

  if (!token) {
    return res.status(400).json({ error: 'token required' });
  }

  const tenant = tenants.find(t => t.namespace === namespace);
  if (!tenant) {
    return res.status(404).json({ error: 'tenant not found' });
  }

  tenant.token = token;
  console.log(`Updated tenant: ${namespace}`);
  res.json({ message: 'tenant updated', tenant });
});

function setTenants(nextTenants) {
  tenants = nextTenants;
}

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Tenants API running on port ${PORT}`);
    console.log(`Initial tenants: ${tenants.length}`);
    tenants.forEach(t => console.log(`  - ${t.namespace}`));
  });
}

module.exports = { app, setTenants };

