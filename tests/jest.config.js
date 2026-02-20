module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/?(*.)+(spec|test).js'],
  modulePaths: ['<rootDir>/node_modules'],
  clearMocks: true,
  restoreMocks: true,
  verbose: true,
  silent: process.env.SHOW_TEST_LOGS !== '1'
};
