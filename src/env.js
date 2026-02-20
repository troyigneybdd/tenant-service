function readEnv(names) {
  for (const name of names) {
    const value = process.env[name];
    if (value !== undefined && value !== '') {
      return value;
    }
  }
  return undefined;
}

function envString(names, defaultValue) {
  const value = readEnv(Array.isArray(names) ? names : [names]);
  return value !== undefined ? value : defaultValue;
}

function envInt(names, defaultValue) {
  const value = readEnv(Array.isArray(names) ? names : [names]);
  if (value === undefined) {
    return defaultValue;
  }
  const parsed = parseInt(value, 10);
  return Number.isNaN(parsed) ? defaultValue : parsed;
}

function envList(names, defaultValue, separator = ',') {
  const value = envString(names, defaultValue);
  if (!value) {
    return [];
  }
  return value.split(separator).map(item => item.trim()).filter(Boolean);
}

function envRequired(names, label) {
  const value = envString(names);
  if (value === undefined) {
    const name = label || (Array.isArray(names) ? names[0] : names);
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

module.exports = {
  envString,
  envInt,
  envList,
  envRequired
};
